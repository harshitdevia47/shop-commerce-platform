import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { AppError, createLogger, findRawPrismaOffenders, getContext, signInternalHeaders, type Role } from '@qc/common';
import { PRESETS, type RuntimeConfig } from '@qc/config-schema';
import type { Express } from 'express';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { createOrderApp } from '../src/app.js';
import { createDb } from '../src/db.js';
import type { CatalogPort, CheckoutAddress, IdentityPort, PaymentPort, PaymentView, VariantSnapshot } from '../src/upstreams.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
const ALICE = randomUUID();
const BOB = randomUUID();
const OWNER = randomUUID();

const RICE = randomUUID();
const DAL = randomUUID();
const B_ITEM = randomUUID();

// ---- Fakes of the other services (state per test) ----

let stock: Map<string, { shopId: string; snapshot: VariantSnapshot }>;
let reservations: Map<string, { shopId: string; items: { variantId: string; qty: number }[]; released: boolean }>;
let paymentCalls: { create: string[]; void: string[] };
let failPaymentCreate: boolean;
let configs: Record<string, RuntimeConfig>;
let addresses: Record<string, CheckoutAddress>;
let blocked: Set<string>;

const shop = () => getContext()!.shopId!;

const catalog: CatalogPort = {
  async lookup(ids) {
    return ids.flatMap((id) => {
      const v = stock.get(id);
      return v && v.shopId === shop() ? [{ ...v.snapshot }] : [];
    });
  },
  async reserve(orderId, items) {
    if (reservations.has(orderId)) return;
    for (const item of items) {
      const v = stock.get(item.variantId);
      if (!v || v.shopId !== shop() || (v.snapshot.stockQty !== null && v.snapshot.stockQty < item.qty)) {
        throw new AppError('OUT_OF_STOCK', 409, 'short', { items: [{ variantId: item.variantId }] });
      }
    }
    for (const item of items) {
      const v = stock.get(item.variantId)!;
      if (v.snapshot.stockQty !== null) v.snapshot.stockQty -= item.qty;
    }
    reservations.set(orderId, { shopId: shop(), items, released: false });
  },
  async release(orderId) {
    const r = reservations.get(orderId);
    if (!r || r.released || r.shopId !== shop()) return;
    r.released = true;
    for (const item of r.items) {
      const v = stock.get(item.variantId)!;
      if (v.snapshot.stockQty !== null) v.snapshot.stockQty += item.qty;
    }
  },
};

const identity: IdentityPort = {
  async checkoutProfile(userId, addressId) {
    const address = addressId ? addresses[addressId] : null;
    if (addressId && !address) throw new AppError('ADDRESS_NOT_FOUND', 404, 'nope');
    return {
      user: { id: userId, phone: userId === ALICE ? '+919800000001' : '+919800000002', name: 'Alice', isBlocked: blocked.has(userId) },
      address: address ?? null,
    };
  },
};

const payments: PaymentPort = {
  async create(input): Promise<PaymentView> {
    paymentCalls.create.push(input.orderId);
    if (failPaymentCreate) throw new AppError('UPSTREAM_UNAVAILABLE', 503, 'payment down');
    return { id: randomUUID(), orderId: input.orderId, method: input.method, status: 'PENDING', amountPaise: input.amountPaise };
  },
  async void(orderId) {
    paymentCalls.void.push(orderId);
  },
};

// ---- Helpers ----

let app: Express;
const sign = (shopId: string, userId?: string, role?: Role) =>
  signInternalHeaders({ requestId: randomUUID(), shopId, userId, role }, SECRET);
const alice = (shopId: string = SHOP_A) => sign(shopId, ALICE, 'CUSTOMER');
const bob = () => sign(SHOP_A, BOB, 'CUSTOMER');
const owner = (shopId: string = SHOP_A) => sign(shopId, OWNER, 'OWNER');
const HOME = randomUUID();

const order = (extra: Record<string, unknown> = {}) => ({
  items: [
    { variantId: RICE, qty: 2 },
    { variantId: DAL, qty: 1 },
  ],
  fulfillment: 'DELIVERY',
  addressId: HOME,
  paymentMethod: 'COD',
  idempotencyKey: randomUUID(),
  ...extra,
});

async function place(body: Record<string, unknown> = order(), headers = alice()) {
  return request(app).post('/api/v1/orders').set(headers).send(body);
}
const qtyOf = (id: string) => stock.get(id)!.snapshot.stockQty;

function snapshot(variantId: string, name: string, pricePaise: number, stockQty: number | null): VariantSnapshot {
  return {
    variantId,
    productId: randomUUID(),
    productName: name,
    productNameI18n: { gu: name },
    label: '1 kg',
    labelI18n: null,
    pricePaise,
    mrpPaise: pricePaise + 1000,
    thumbUrl: '/media/x.webp',
    inStock: true,
    stockQty,
  };
}

beforeAll(() => {
  app = createOrderApp({
    db,
    logger: createLogger('order-test', 'silent'),
    internalSecret: SECRET,
    shopConfig: { get: async () => configs[shop()]! },
    catalog,
    identity,
    payments,
  });
});

async function clean() {
  const where = { shopId: { in: [SHOP_A, SHOP_B] } };
  await rawPrisma.orderStatusChange.deleteMany({ where });
  await rawPrisma.orderItem.deleteMany({ where });
  await rawPrisma.order.deleteMany({ where });
  await rawPrisma.orderCounter.deleteMany({ where });
}

beforeEach(async () => {
  await clean();
  stock = new Map([
    [RICE, { shopId: SHOP_A, snapshot: snapshot(RICE, 'Rice', 12000, 10) }],
    [DAL, { shopId: SHOP_A, snapshot: snapshot(DAL, 'Dal', 8000, null) }],
    [B_ITEM, { shopId: SHOP_B, snapshot: snapshot(B_ITEM, 'Shirt', 79900, null) }],
  ]);
  reservations = new Map();
  paymentCalls = { create: [], void: [] };
  failPaymentCreate = false;
  blocked = new Set();
  const base = (shopId: string): RuntimeConfig => ({
    shop: {
      name: 'Shop',
      businessType: 'grocery',
      currency: 'INR',
      timezone: 'Asia/Kolkata',
      contact: { phone: '+919876543210', address: 'x', lat: 21.7645, lng: 72.1519 },
    },
    delivery: { enabled: true, radiusKm: 5, pincodes: ['364001'], minOrderPaise: 10000, feePaise: 2000, freeAbovePaise: 50000, etaMinutes: 45 },
    payments: { cod: true, upi: { enabled: false }, razorpay: { enabled: false } },
    features: { ...PRESETS.grocery.features, storePickup: shopId === SHOP_A, orderNotes: true },
    catalog: PRESETS.grocery.catalog,
  });
  configs = { [SHOP_A]: base(SHOP_A), [SHOP_B]: base(SHOP_B) };
  addresses = {
    [HOME]: { id: HOME, label: 'home', name: null, phone: null, line1: 'Station Rd', line2: null, landmark: null, city: 'Bhavnagar', pincode: '364001', lat: 21.77, lng: 72.15 },
  };
});

afterAll(async () => {
  await clean();
  await rawPrisma.$disconnect();
});

// ---- Tests ----

describe('quote', () => {
  it('prices from catalog data, for guests too', async () => {
    const res = await request(app)
      .post('/api/v1/orders/quote')
      .set(sign(SHOP_A))
      .send({ items: [{ variantId: RICE, qty: 2 }, { variantId: DAL, qty: 1 }] });
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ subtotalPaise: 32000, deliveryFeePaise: 2000, totalPaise: 34000, canPlace: true });
  });

  it("does not price another shop's items", async () => {
    const res = await request(app).post('/api/v1/orders/quote').set(sign(SHOP_A)).send({ items: [{ variantId: B_ITEM, qty: 1 }] });
    expect(res.body.data).toMatchObject({ missing: [B_ITEM], canPlace: false });
  });
});

describe('place order', () => {
  it('reserves stock, numbers the order, creates the payment and snapshots everything', async () => {
    const res = await place(order({ note: 'Ring the bell' }));
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const { order: placed, payment } = res.body.data;
    expect(placed).toMatchObject({
      number: 1,
      status: 'PLACED',
      fulfillment: 'DELIVERY',
      note: 'Ring the bell',
      subtotalPaise: 32000,
      deliveryFeePaise: 2000,
      totalPaise: 34000,
      itemCount: 3,
      address: { pincode: '364001' },
      customer: { phone: '+919800000001' },
      nextStatuses: ['CANCELLED'],
      history: [{ status: 'PLACED', byRole: 'CUSTOMER' }],
    });
    expect(placed.items[0]).toMatchObject({ productName: 'Rice', productNameI18n: { gu: 'Rice' }, qty: 2, lineTotalPaise: 24000 });
    expect(payment).toMatchObject({ orderId: placed.id, amountPaise: 34000 });
    expect(qtyOf(RICE)).toBe(8);

    // Snapshot survives later price changes.
    stock.get(RICE)!.snapshot.pricePaise = 99900;
    const again = await request(app).get(`/api/v1/orders/${placed.id}`).set(alice());
    expect(again.body.data.items[0].pricePaise).toBe(12000);
  });

  it('numbers orders per shop', async () => {
    await place();
    const second = await place();
    expect(second.body.data.order.number).toBe(2);
    const otherShop = await place(order({ items: [{ variantId: B_ITEM, qty: 1 }] }), alice(SHOP_B));
    expect(otherShop.body.data.order.number).toBe(1);
  });

  it('the same idempotency key never creates a second order', async () => {
    const body = order();
    const first = await place(body);
    const retry = await place(body);
    expect(retry.status).toBe(201);
    expect(retry.body.data.order.id).toBe(first.body.data.order.id);
    expect(qtyOf(RICE)).toBe(8);
    expect(paymentCalls.create).toHaveLength(1);
  });

  it('parallel double tap with one key ends with one order and stock held once', async () => {
    const body = order();
    const results = await Promise.all([place(body), place(body), place(body)]);
    const ids = new Set(results.map((r) => r.body.data?.order?.id));
    expect(ids.size).toBe(1);
    expect(await rawPrisma.order.count({ where: { shopId: SHOP_A } })).toBe(1);
    expect(qtyOf(RICE)).toBe(8);
  });

  it('refuses when an item ran out, returning the fresh quote', async () => {
    stock.get(RICE)!.snapshot.stockQty = 1;
    const res = await place();
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('CART_CHANGED');
    expect(res.body.error.details.quote.lines[0]).toMatchObject({ issue: 'INSUFFICIENT_STOCK', maxQty: 1 });
  });

  it('refuses when the price changed since the customer looked', async () => {
    const res = await place(order({ expectedTotalPaise: 30000 }));
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('PRICE_CHANGED');
    expect(res.body.error.details.quote.totalPaise).toBe(34000);
  });

  it('enforces minimum order, delivery area, pickup and note flags', async () => {
    const small = await place(order({ items: [{ variantId: DAL, qty: 1 }] }));
    expect(small.body.error).toMatchObject({ code: 'BELOW_MINIMUM_ORDER', details: { minOrderPaise: 10000 } });

    addresses[HOME]!.pincode = '380001';
    expect((await place()).body.error.code).toBe('OUTSIDE_DELIVERY_AREA');
    addresses[HOME]!.pincode = '364001';
    addresses[HOME]!.lat = 23.0225; // Ahmedabad: far outside 5 km
    addresses[HOME]!.lng = 72.5714;
    expect((await place()).body.error.code).toBe('OUTSIDE_DELIVERY_AREA');

    expect((await place(order({ addressId: undefined }))).body.error.code).toBe('ADDRESS_REQUIRED');
    const pickup = await place(order({ fulfillment: 'PICKUP', addressId: undefined, items: [{ variantId: DAL, qty: 1 }] }));
    expect(pickup.status).toBe(201); // pickup: no fee, no minimum
    expect(pickup.body.data.order).toMatchObject({ deliveryFeePaise: 0, address: null });

    expect((await place(order({ items: [{ variantId: B_ITEM, qty: 1 }], fulfillment: 'PICKUP' }), alice(SHOP_B))).body.error.code).toBe(
      'PICKUP_UNAVAILABLE',
    );
    configs[SHOP_A]!.features.orderNotes = false;
    expect((await place(order({ note: 'hi' }))).body.error.code).toBe('FEATURE_DISABLED');
  });

  it('blocked customers cannot order', async () => {
    blocked.add(ALICE);
    expect((await place()).body.error.code).toBe('USER_BLOCKED');
  });

  it('gives stock back when the payment step fails', async () => {
    failPaymentCreate = true;
    const res = await place();
    expect(res.status).toBe(503);
    expect(qtyOf(RICE)).toBe(10);
    expect(await rawPrisma.order.count({ where: { shopId: SHOP_A } })).toBe(0);
  });

  it('needs login', async () => {
    expect((await place(order(), sign(SHOP_A))).status).toBe(401);
  });
});

describe('status changes', () => {
  async function placed() {
    return (await place()).body.data.order as { id: string };
  }
  const setStatus = (id: string, status: string, reason?: string, headers = owner()) =>
    request(app).post(`/api/v1/admin/orders/${id}/status`).set(headers).send({ status, reason });

  it('shop walks an order to delivered; history records each step', async () => {
    const { id } = await placed();
    for (const status of ['CONFIRMED', 'PACKED', 'OUT_FOR_DELIVERY', 'DELIVERED']) {
      const res = await setStatus(id, status);
      expect(res.status, `${status}: ${JSON.stringify(res.body)}`).toBe(200);
    }
    const res = await request(app).get(`/api/v1/admin/orders/${id}`).set(owner());
    expect(res.body.data.history.map((h: { status: string }) => h.status)).toEqual([
      'PLACED',
      'CONFIRMED',
      'PACKED',
      'OUT_FOR_DELIVERY',
      'DELIVERED',
    ]);
    expect(res.body.data.nextStatuses).toEqual([]);
    expect(paymentCalls.void).toEqual([]);
  });

  it('refuses skipping steps and wrong fulfillment paths', async () => {
    const { id } = await placed();
    expect((await setStatus(id, 'DELIVERED')).body.error.code).toBe('ORDER_STATUS_INVALID');
    await setStatus(id, 'CONFIRMED');
    await setStatus(id, 'PACKED');
    expect((await setStatus(id, 'READY_FOR_PICKUP')).body.error.code).toBe('ORDER_STATUS_INVALID');
  });

  it('rejecting needs a reason and gives stock back and voids the payment', async () => {
    const { id } = await placed();
    expect((await setStatus(id, 'REJECTED')).body.error.code).toBe('REASON_REQUIRED');
    const res = await setStatus(id, 'REJECTED', 'Out of rice today');
    expect(res.body.data).toMatchObject({ status: 'REJECTED', cancelReason: 'Out of rice today' });
    expect(qtyOf(RICE)).toBe(10);
    expect(paymentCalls.void).toEqual([id]);
  });

  it('customer cancels before packing, not after', async () => {
    const first = await placed();
    const cancelled = await request(app).post(`/api/v1/orders/${first.id}/cancel`).set(alice()).send({ reason: 'Ordered by mistake' });
    expect(cancelled.body.data.status).toBe('CANCELLED');
    expect(qtyOf(RICE)).toBe(10);

    const second = await placed();
    await setStatus(second.id, 'CONFIRMED');
    await setStatus(second.id, 'PACKED');
    const late = await request(app).post(`/api/v1/orders/${second.id}/cancel`).set(alice()).send({});
    expect(late.body.error.code).toBe('ORDER_NOT_CANCELLABLE');
  });

  it('customers cannot use the shop status endpoint', async () => {
    const { id } = await placed();
    expect((await setStatus(id, 'CONFIRMED', undefined, alice())).status).toBe(403);
  });

  it('two staff confirming at once: one wins, one gets a conflict', async () => {
    const { id } = await placed();
    const results = await Promise.all([setStatus(id, 'CONFIRMED'), setStatus(id, 'CONFIRMED')]);
    expect(results.map((r) => r.status).sort()).toEqual([200, 409]);
    const history = await rawPrisma.orderStatusChange.count({ where: { orderId: id } });
    expect(history).toBe(2);
  });
});

describe('lists', () => {
  it('customer sees own orders newest first, paginated', async () => {
    const ids = [];
    for (let i = 0; i < 3; i++) ids.push((await place()).body.data.order.id);
    await place(order(), bob());
    const page1 = await request(app).get('/api/v1/orders?limit=2').set(alice());
    expect(page1.body.data.map((o: { id: string }) => o.id)).toEqual([ids[2], ids[1]]);
    const page2 = await request(app).get(`/api/v1/orders?limit=2&cursor=${page1.body.nextCursor}`).set(alice());
    expect(page2.body).toMatchObject({ data: [{ id: ids[0] }], nextCursor: null });
  });

  it('shop groups: new (oldest first), active, done', async () => {
    const a = (await place()).body.data.order.id;
    const b = (await place()).body.data.order.id;
    const c = (await place()).body.data.order.id;
    await request(app).post(`/api/v1/admin/orders/${b}/status`).set(owner()).send({ status: 'CONFIRMED' });
    await request(app).post(`/api/v1/orders/${c}/cancel`).set(alice()).send({});
    const group = async (g: string) =>
      (await request(app).get(`/api/v1/admin/orders?group=${g}`).set(owner())).body.data.map((o: { id: string }) => o.id);
    expect(await group('new')).toEqual([a]);
    expect(await group('active')).toEqual([b]);
    expect(await group('done')).toEqual([c]);
  });
});

describe('tenant and customer isolation', () => {
  it("another customer, or another shop, gets 404 for an order", async () => {
    const { id } = (await place()).body.data.order;
    expect((await request(app).get(`/api/v1/orders/${id}`).set(bob())).status).toBe(404);
    expect((await request(app).post(`/api/v1/orders/${id}/cancel`).set(bob()).send({})).status).toBe(404);
    expect((await request(app).get(`/api/v1/admin/orders/${id}`).set(owner(SHOP_B))).status).toBe(404);
    expect((await request(app).post(`/api/v1/admin/orders/${id}/status`).set(owner(SHOP_B)).send({ status: 'CONFIRMED' })).status).toBe(404);
    expect((await request(app).get('/api/v1/admin/orders').set(owner(SHOP_B))).body.data).toEqual([]);
    expect((await request(app).get(`/api/v1/orders/${id}`).set(alice(SHOP_B))).status).toBe(404);
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    expect(findRawPrismaOffenders(fileURLToPath(new URL('../src/', import.meta.url)))).toEqual([]);
  });
});
