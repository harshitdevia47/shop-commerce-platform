import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createLogger, findRawPrismaOffenders, runWithContext, signInternalHeaders, type Role } from '@qc/common';
import { buildEvent, onceOnly, prismaProcessedEvents, type AnyEvent } from '@qc/events';
import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createReportingApp } from '../src/app.js';
import { salesProjector, shopDay } from '../src/consumers/sales-projector.js';
import { createDb } from '../src/db.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const app = createReportingApp({ db, logger: createLogger('reporting-test', 'silent'), internalSecret: SECRET });
const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
const ALICE = randomUUID();
const BOB = randomUUID();
const RICE = { productId: randomUUID(), variantId: randomUUID(), productName: 'Rice', variantLabel: '1 kg' };
const DAL = { productId: randomUUID(), variantId: randomUUID(), productName: 'Dal', variantLabel: '500 g' };

const project = onceOnly(prismaProcessedEvents(db.processedEvent), salesProjector(db));
const deliver = (event: AnyEvent) => runWithContext({ requestId: event.eventId, shopId: event.shopId }, () => project(event));
const as = (shopId: string, role: Role = 'OWNER') => signInternalHeaders({ requestId: randomUUID(), shopId, userId: randomUUID(), role }, SECRET);
const get = (path: string, headers = as(SHOP_A)) => request(app).get(`/api/v1/admin/reports/${path}`).set(headers);

let number = 0;
/** Places an order at `at` (UTC instant) and returns its id. */
async function placed(at: string, opts: { customer?: string; total?: number; method?: 'COD' | 'UPI'; shop?: string; items?: { line: typeof RICE; qty: number; paise: number }[]; list?: boolean } = {}) {
  const orderId = randomUUID();
  const items = opts.items ?? [{ line: RICE, qty: 2, paise: 24_000 }];
  const event = buildEvent(
    'order.placed',
    opts.shop ?? SHOP_A,
    {
      orderId,
      number: ++number,
      customerId: opts.customer ?? ALICE,
      totalPaise: opts.list ? 0 : (opts.total ?? items.reduce((n, i) => n + i.paise, 0)),
      itemCount: opts.list ? 0 : items.reduce((n, i) => n + i.qty, 0),
      fulfillment: 'DELIVERY',
      paymentMethod: opts.method ?? 'COD',
      needsPricing: opts.list ?? false,
      items: opts.list ? [] : items.map((i) => ({ ...i.line, qty: i.qty, lineTotalPaise: i.paise })),
    },
    { now: new Date(at) },
  );
  await deliver(event);
  return { orderId, event };
}

async function status(orderId: string, to: string, at: string, extra: Record<string, unknown> = {}, shop = SHOP_A) {
  await deliver(
    buildEvent(
      'order.status_changed',
      shop,
      {
        orderId,
        number: 1,
        customerId: ALICE,
        fulfillment: 'DELIVERY',
        from: 'PLACED',
        to: to as 'DELIVERED',
        byRole: 'OWNER',
        reason: null,
        ...extra,
      },
      { now: new Date(at) },
    ),
  );
}

async function paid(orderId: string, at: string) {
  await deliver(buildEvent('payment.marked_paid', SHOP_A, { orderId, orderNumber: 1, customerId: ALICE, amountPaise: 1 }, { now: new Date(at) }));
}

async function clean() {
  const where = { shopId: { in: [SHOP_A, SHOP_B] } };
  await rawPrisma.saleItem.deleteMany({ where });
  await rawPrisma.saleOrder.deleteMany({ where });
  await rawPrisma.salePayment.deleteMany({ where });
  await rawPrisma.processedEvent.deleteMany({ where });
}
beforeEach(clean);
afterAll(async () => {
  await clean();
  await rawPrisma.$disconnect();
});

describe('shop day', () => {
  it('uses the Indian calendar day', () => {
    expect(shopDay(new Date('2026-11-23T18:29:00Z')).toISOString()).toBe('2026-11-23T00:00:00.000Z'); // 23:59 IST
    expect(shopDay(new Date('2026-11-23T18:30:00Z')).toISOString()).toBe('2026-11-24T00:00:00.000Z'); // 00:00 IST
  });
});

describe('sales summary', () => {
  it('counts sales, cancellations, payment split, paid amount and new vs returning customers', async () => {
    // Bob ordered last week: returning in this period. Alice orders for the first time.
    await placed('2026-11-17T05:00:00Z', { customer: BOB });
    const a = await placed('2026-11-23T05:00:00Z', { items: [{ line: RICE, qty: 2, paise: 24_000 }, { line: DAL, qty: 1, paise: 9_000 }] });
    const b = await placed('2026-11-23T06:00:00Z', { customer: BOB, method: 'UPI', items: [{ line: DAL, qty: 3, paise: 27_000 }] });
    const c = await placed('2026-11-24T05:00:00Z', { items: [{ line: RICE, qty: 1, paise: 12_000 }] });
    await status(a.orderId, 'DELIVERED', '2026-11-23T09:00:00Z');
    await status(b.orderId, 'DELIVERED', '2026-11-23T10:00:00Z');
    await paid(b.orderId, '2026-11-23T10:05:00Z');
    await status(c.orderId, 'CANCELLED', '2026-11-24T05:10:00Z');

    const res = await get('summary?from=2026-11-23&to=2026-11-24');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body.data).toEqual({
      from: '2026-11-23',
      to: '2026-11-24',
      orders: 2,
      cancelled: 1,
      open: 0,
      completed: 2,
      salesPaise: 60_000,
      completedPaise: 60_000,
      averageOrderPaise: 30_000,
      paidPaise: 27_000,
      cod: { orders: 1, paise: 33_000 },
      upi: { orders: 1, paise: 27_000 },
      delivery: 2,
      pickup: 0,
      customers: 2,
      newCustomers: 1,
      returningCustomers: 1,
    });
  });

  it('list orders count once the shop prices them', async () => {
    const list = await placed('2026-11-23T05:00:00Z', { list: true, method: 'UPI' });
    expect((await get('summary?from=2026-11-23&to=2026-11-23')).body.data.salesPaise).toBe(0);
    await status(list.orderId, 'CONFIRMED', '2026-11-23T05:30:00Z', { pricedTotalPaise: 45_600 });
    expect((await get('summary?from=2026-11-23&to=2026-11-23')).body.data).toMatchObject({ salesPaise: 45_600, open: 1 });
  });

  it('replayed events and early payments do not change the numbers', async () => {
    const a = await placed('2026-11-23T05:00:00Z');
    await paid(randomUUID(), '2026-11-23T05:00:00Z'); // payment of an order not seen yet: kept, harmless
    await deliver(a.event); // same event again (relay re-publish)
    await deliver({ ...a.event, eventId: randomUUID() }); // or a duplicate with a new id (replay)
    const data = (await get('summary?from=2026-11-23&to=2026-11-23')).body.data;
    expect(data).toMatchObject({ orders: 1, salesPaise: 24_000 });
  });
});

describe('daily and top products', () => {
  it('fills every day and ranks products by sales', async () => {
    await placed('2026-11-21T05:00:00Z', { items: [{ line: RICE, qty: 1, paise: 12_000 }] });
    await placed('2026-11-23T05:00:00Z', { items: [{ line: DAL, qty: 5, paise: 45_000 }, { line: RICE, qty: 1, paise: 12_000 }] });
    const cancelled = await placed('2026-11-23T06:00:00Z', { items: [{ line: RICE, qty: 10, paise: 120_000 }] });
    await status(cancelled.orderId, 'REJECTED', '2026-11-23T06:05:00Z');

    const daily = (await get('daily?from=2026-11-21&to=2026-11-23')).body.data;
    expect(daily).toEqual([
      { day: '2026-11-21', orders: 1, salesPaise: 12_000 },
      { day: '2026-11-22', orders: 0, salesPaise: 0 },
      { day: '2026-11-23', orders: 1, salesPaise: 57_000 },
    ]);
    const top = (await get('top-products?from=2026-11-21&to=2026-11-23&limit=5')).body.data;
    expect(top).toEqual([
      { productId: DAL.productId, productName: 'Dal', qty: 5, salesPaise: 45_000 },
      { productId: RICE.productId, productName: 'Rice', qty: 2, salesPaise: 24_000 },
    ]);
  });
});

describe('access', () => {
  it('owner only; each shop sees its own sales; ranges are checked', async () => {
    await placed('2026-11-23T05:00:00Z');
    await placed('2026-11-23T05:00:00Z', { shop: SHOP_B, total: 99_900 });
    expect((await get('summary?from=2026-11-23&to=2026-11-23', as(SHOP_A, 'STAFF'))).status).toBe(403);
    expect((await get('summary?from=2026-11-23&to=2026-11-23', as(SHOP_A, 'CUSTOMER'))).status).toBe(403);
    expect((await get('summary?from=2026-11-23&to=2026-11-23')).body.data.salesPaise).toBe(24_000);
    expect((await get('summary?from=2026-11-23&to=2026-11-23', as(SHOP_B))).body.data.salesPaise).toBe(99_900);
    expect((await get('summary?from=2026-11-24&to=2026-11-23')).body.error.code).toBe('RANGE_INVALID');
    expect((await get('daily?from=2025-01-01&to=2026-11-23')).body.error.code).toBe('RANGE_TOO_LONG');
    expect((await get('summary?from=yesterday&to=2026-11-23')).status).toBe(400);
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    expect(findRawPrismaOffenders(fileURLToPath(new URL('../src/', import.meta.url)))).toEqual([]);
  });
});
