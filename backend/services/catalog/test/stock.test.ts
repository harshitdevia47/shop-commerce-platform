import { randomUUID } from 'node:crypto';
import { createLogger, signInternalHeaders } from '@qc/common';
import { PRESETS } from '@qc/config-schema';
import type { Express } from 'express';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { createCatalogApp } from '../src/app.js';
import { createDb } from '../src/db.js';
import { getContext, runWithContext } from '@qc/common';
import { buildEvent, type AnyEvent } from '@qc/events';
import { orderEventsHandler } from '../src/consumers/order-events.js';
import { sweepOrphanReservations } from '../src/jobs/orphan-sweeper.js';
import { createStockService } from '../src/modules/stock/stock.service.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
let app: Express;

/** Signed as the order service calling in the context of a shop (no user). */
const svc = (shopId: string = SHOP_A) => signInternalHeaders({ requestId: randomUUID(), shopId }, SECRET);
const owner = (shopId: string = SHOP_A) =>
  signInternalHeaders({ requestId: randomUUID(), shopId, userId: randomUUID(), role: 'OWNER' }, SECRET);

async function product(stockQty: number | null, extra: Record<string, unknown> = {}, shopId: string = SHOP_A) {
  const res = await request(app)
    .post('/api/v1/admin/catalog/products')
    .set(owner(shopId))
    .send({ name: 'Rice', variants: [{ label: '1 kg', pricePaise: 10000, stockQty }], ...extra });
  expect(res.status, JSON.stringify(res.body)).toBe(201);
  return { productId: res.body.data.id as string, variantId: res.body.data.variants[0].id as string };
}

const stockOf = async (variantId: string) => (await rawPrisma.variant.findUniqueOrThrow({ where: { id: variantId } })).stockQty;
const reserve = (orderId: string, items: { variantId: string; qty: number }[], shopId: string = SHOP_A) =>
  request(app).post('/internal/catalog/stock/reserve').set(svc(shopId)).send({ orderId, items });
const release = (orderId: string, shopId: string = SHOP_A) =>
  request(app).post('/internal/catalog/stock/release').set(svc(shopId)).send({ orderId });

beforeAll(() => {
  app = createCatalogApp({
    db,
    logger: createLogger('stock-test', 'silent'),
    internalSecret: SECRET,
    settings: { get: async () => PRESETS.grocery.catalog },
    media: { resolve: async () => [] },
  });
});

async function clean() {
  const where = { shopId: { in: [SHOP_A, SHOP_B] } };
  await rawPrisma.stockReservation.deleteMany({ where });
  await rawPrisma.processedEvent.deleteMany({ where });
  await rawPrisma.productImage.deleteMany({ where });
  await rawPrisma.variant.deleteMany({ where });
  await rawPrisma.product.deleteMany({ where });
}
beforeEach(clean);
afterAll(async () => {
  await clean();
  await rawPrisma.$disconnect();
});

describe('variant lookup', () => {
  it('returns price, names and availability for the shop', async () => {
    const { variantId, productId } = await product(5, { nameI18n: { gu: 'ચોખા' } });
    const res = await request(app).post('/internal/catalog/variants/lookup').set(svc()).send({ ids: [variantId, randomUUID()] });
    expect(res.body.data).toEqual([
      expect.objectContaining({
        variantId,
        productId,
        productName: 'Rice',
        productNameI18n: { gu: 'ચોખા' },
        label: '1 kg',
        pricePaise: 10000,
        inStock: true,
        stockQty: 5,
      }),
    ]);
  });

  it('marks hidden products as not in stock and hides other shops', async () => {
    const hidden = await product(null, { isActive: false });
    const foreign = await product(null, {}, SHOP_B);
    const res = await request(app)
      .post('/internal/catalog/variants/lookup')
      .set(svc())
      .send({ ids: [hidden.variantId, foreign.variantId] });
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0]).toMatchObject({ variantId: hidden.variantId, inStock: false });
  });
});

describe('reserve / release', () => {
  it('decrements tracked stock and gives it back on release', async () => {
    const { variantId } = await product(5);
    const orderId = randomUUID();
    expect((await reserve(orderId, [{ variantId, qty: 2 }, { variantId, qty: 1 }])).status).toBe(200);
    expect(await stockOf(variantId)).toBe(2);

    await release(orderId).expect(200);
    expect(await stockOf(variantId)).toBe(5);
    await release(orderId).expect(200); // idempotent
    expect(await stockOf(variantId)).toBe(5);
  });

  it('is idempotent per order', async () => {
    const { variantId } = await product(5);
    const orderId = randomUUID();
    await reserve(orderId, [{ variantId, qty: 2 }]).expect(200);
    await reserve(orderId, [{ variantId, qty: 2 }]).expect(200);
    expect(await stockOf(variantId)).toBe(3);
  });

  it('is all or nothing and reports what is short', async () => {
    const a = await product(5);
    const b = await product(1);
    const res = await reserve(randomUUID(), [
      { variantId: a.variantId, qty: 2 },
      { variantId: b.variantId, qty: 3 },
    ]);
    expect(res.status).toBe(409);
    expect(res.body.error).toMatchObject({
      code: 'OUT_OF_STOCK',
      details: { items: [{ variantId: b.variantId, requested: 3, available: 1 }] },
    });
    expect(await stockOf(a.variantId)).toBe(5); // rolled back
  });

  it('never oversells under concurrent orders', async () => {
    const { variantId } = await product(3);
    const results = await Promise.all(
      Array.from({ length: 8 }, () => reserve(randomUUID(), [{ variantId, qty: 1 }])),
    );
    expect(results.filter((r) => r.status === 200)).toHaveLength(3);
    expect(results.filter((r) => r.status === 409)).toHaveLength(5);
    expect(await stockOf(variantId)).toBe(0);
  });

  it('untracked stock is always available and stays untracked', async () => {
    const { variantId } = await product(null);
    const orderId = randomUUID();
    await reserve(orderId, [{ variantId, qty: 500 }]).expect(200);
    await release(orderId).expect(200);
    expect(await stockOf(variantId)).toBeNull();
  });

  it('refuses hidden, unavailable and deleted products', async () => {
    const hidden = await product(null, { isActive: false });
    expect((await reserve(randomUUID(), [{ variantId: hidden.variantId, qty: 1 }])).status).toBe(409);
    const off = await product(null);
    await request(app).patch(`/api/v1/admin/catalog/variants/${off.variantId}`).set(owner()).send({ isAvailable: false }).expect(200);
    expect((await reserve(randomUUID(), [{ variantId: off.variantId, qty: 1 }])).status).toBe(409);
  });

  it("cannot reserve or release another shop's stock", async () => {
    const { variantId } = await product(5, {}, SHOP_B);
    const res = await reserve(randomUUID(), [{ variantId, qty: 1 }], SHOP_A);
    expect(res.status).toBe(409);
    expect(await stockOf(variantId)).toBe(5);

    const orderId = randomUUID();
    await reserve(orderId, [{ variantId, qty: 2 }], SHOP_B).expect(200);
    await release(orderId, SHOP_A).expect(200); // nothing of shop A's to release
    expect(await stockOf(variantId)).toBe(3);
  });

  it('is not reachable without a shop context', async () => {
    const res = await request(app)
      .post('/internal/catalog/stock/reserve')
      .set(signInternalHeaders({ requestId: randomUUID() }, SECRET))
      .send({ orderId: randomUUID(), items: [{ variantId: randomUUID(), qty: 1 }] });
    expect(res.status).toBe(400);
  });
});

describe('order events and orphan sweeper', () => {
  const stock = createStockService(db);
  const deliver = (event: AnyEvent) =>
    runWithContext({ requestId: event.eventId, shopId: event.shopId }, () => orderEventsHandler(stock)(event));
  const changed = (orderId: string, to: 'REJECTED' | 'PACKED', shopId = SHOP_A) =>
    buildEvent('order.status_changed', shopId, {
      orderId,
      number: 1,
      customerId: randomUUID(),
      fulfillment: 'DELIVERY',
      from: 'PLACED',
      to,
      byRole: 'OWNER',
      reason: to === 'REJECTED' ? 'closed' : null,
    });

  it('a rejected order gives stock back once, even if the event repeats', async () => {
    const { variantId } = await product(10);
    const orderId = randomUUID();
    await reserve(orderId, [{ variantId, qty: 4 }]);
    await deliver(changed(orderId, 'PACKED'));
    expect(await stockOf(variantId)).toBe(6);
    await deliver(changed(orderId, 'REJECTED'));
    await deliver(changed(orderId, 'REJECTED'));
    expect(await stockOf(variantId)).toBe(10);
  });

  it("events never release another shop's stock", async () => {
    const { variantId } = await product(10);
    const orderId = randomUUID();
    await reserve(orderId, [{ variantId, qty: 4 }]);
    await deliver(changed(orderId, 'REJECTED', SHOP_B));
    expect(await stockOf(variantId)).toBe(6);
  });

  it('order.placed commits; the sweeper releases only reservations whose order does not exist', async () => {
    const { variantId } = await product(10);
    const placedOrder = randomUUID();
    const realOrder = randomUUID();
    const orphan = randomUUID();
    for (const id of [placedOrder, realOrder, orphan]) await reserve(id, [{ variantId, qty: 2 }]);
    await deliver(
      buildEvent('order.placed', SHOP_A, {
        orderId: placedOrder,
        number: 1,
        customerId: randomUUID(),
        totalPaise: 100,
        itemCount: 1,
        fulfillment: 'PICKUP',
        paymentMethod: 'COD',
      }),
    );
    expect(await stockOf(variantId)).toBe(4);

    const stale = async () =>
      (await rawPrisma.stockReservation.findMany({ where: { shopId: SHOP_A, committedAt: null, releasedAt: null } })).map((r) => ({
        shopId: r.shopId,
        orderId: r.orderId,
      }));
    expect((await stale()).map((r) => r.orderId).sort()).toEqual([realOrder, orphan].sort());
    const result = await sweepOrphanReservations(
      stale,
      { existing: async (ids) => (getContext()!.shopId === SHOP_A ? ids.filter((id) => id === realOrder) : []) },
      stock,
      createLogger('sweeper-test', 'silent'),
    );
    expect(result).toEqual({ committed: 1, released: 1 });
    expect(await stockOf(variantId)).toBe(6);
    expect(await stale()).toEqual([]);
  });
});
