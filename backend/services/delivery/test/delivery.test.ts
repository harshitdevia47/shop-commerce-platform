import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { AppError, createLogger, findRawPrismaOffenders, getContext, runWithContext, signInternalHeaders, type Role } from '@qc/common';
import { buildEvent } from '@qc/events';
import type { Express } from 'express';
import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createDeliveryApp } from '../src/app.js';
import { orderEventsHandler } from '../src/consumers/order-events.js';
import { createDb } from '../src/db.js';
import { createDeliveriesService } from '../src/modules/deliveries/deliveries.service.js';
import { memoryLocationStore, type OrderSnapshot, type Rider } from '../src/upstreams.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
const ALICE = randomUUID();
const BOB = randomUUID();
const OWNER = randomUUID();
const RAJU: Rider = { id: randomUUID(), name: 'Raju', phone: '+919811100001' };
const VIKAS: Rider = { id: randomUUID(), name: 'Vikas', phone: '+919811100002' };
const B_RIDER: Rider = { id: randomUUID(), name: 'Other', phone: '+919811100003' };

// ---- Fake order service: enforces the same rider transitions as the real one ----
let orders: Map<string, OrderSnapshot & { shopId: string }>;
let statusCalls: { orderId: string; status: string; role?: string }[];
const shop = () => getContext()!.shopId!;

const orderPort = {
  async get(orderId: string) {
    const o = orders.get(orderId);
    if (!o || o.shopId !== shop()) throw new AppError('ORDER_NOT_FOUND', 404, 'Order not found');
    return o;
  },
  async setStatus(orderId: string, status: 'OUT_FOR_DELIVERY' | 'DELIVERED') {
    const o = await orderPort.get(orderId);
    statusCalls.push({ orderId, status, role: getContext()?.role });
    const ok = (status === 'OUT_FOR_DELIVERY' && o.status === 'PACKED') || (status === 'DELIVERED' && o.status === 'OUT_FOR_DELIVERY');
    if (!ok) throw new AppError('ORDER_STATUS_INVALID', 409, 'no');
    o.status = status;
    return o;
  },
};
const identity = { riders: async () => (shop() === SHOP_A ? [RAJU, VIKAS] : [B_RIDER]) };
const locations = memoryLocationStore();
const deliveries = createDeliveriesService({ db, logger: createLogger('delivery-test', 'silent'), orders: orderPort, identity, locations });
const app: Express = createDeliveryApp({ db, logger: createLogger('delivery-test', 'silent'), internalSecret: SECRET, deliveries });

const sign = (shopId: string, userId?: string, role?: Role) => signInternalHeaders({ requestId: randomUUID(), shopId, userId, role }, SECRET);
const owner = (shopId = SHOP_A) => sign(shopId, OWNER, 'OWNER');
const rider = (r: Rider = RAJU, shopId = SHOP_A) => sign(shopId, r.id, 'RIDER');
const customer = (id = ALICE, shopId = SHOP_A) => sign(shopId, id, 'CUSTOMER');

function newOrder(extra: Partial<OrderSnapshot> = {}, shopId = SHOP_A): string {
  const id = randomUUID();
  orders.set(id, {
    shopId,
    id,
    number: orders.size + 1,
    status: 'PACKED',
    fulfillment: 'DELIVERY',
    address: { name: null, phone: null, line1: '12 Station Rd', line2: null, landmark: 'Temple', city: 'Bhavnagar', pincode: '364001', lat: 21.77, lng: 72.15 },
    note: 'Ring twice',
    paymentMethod: 'COD',
    customer: { id: ALICE, phone: '+919800000001', name: 'Alice' },
    itemCount: 3,
    totalPaise: 34_000,
    ...extra,
  });
  return id;
}

const assign = (orderId: string, riderId = RAJU.id, headers = owner()) =>
  request(app).post('/api/v1/admin/deliveries').set(headers).send({ orderId, riderId });
const deliveryOf = (orderId: string) => rawPrisma.delivery.findFirstOrThrow({ where: { orderId } });
const events = async () =>
  (await rawPrisma.outboxEvent.findMany({ where: { shopId: { in: [SHOP_A, SHOP_B] } }, orderBy: { id: 'asc' } })).map(
    (e) => (e.envelope as { payload: Record<string, unknown> }).payload,
  );

async function assigned(extra: Partial<OrderSnapshot> = {}) {
  const orderId = newOrder(extra);
  const res = await assign(orderId);
  expect(res.status, JSON.stringify(res.body)).toBe(200);
  return { orderId, id: res.body.data.id as string };
}

async function clean() {
  const where = { shopId: { in: [SHOP_A, SHOP_B] } };
  await rawPrisma.delivery.deleteMany({ where });
  await rawPrisma.outboxEvent.deleteMany({ where });
  await rawPrisma.processedEvent.deleteMany({ where });
}

beforeEach(async () => {
  await clean();
  orders = new Map();
  statusCalls = [];
});

afterAll(async () => {
  await clean();
  await rawPrisma.$disconnect();
});

describe('assigning riders', () => {
  it('snapshots the order for the rider, makes a door code for the customer, and announces it', async () => {
    const { orderId, id } = await assigned();
    const row = await deliveryOf(orderId);
    expect(row).toMatchObject({ status: 'ASSIGNED', riderId: RAJU.id, riderName: 'Raju', codPaise: 34_000, customerPhone: '+919800000001' });
    expect(row.otp).toMatch(/^\d{4}$/);
    expect(await events()).toEqual([
      { deliveryId: id, orderId, number: 1, customerId: ALICE, riderId: RAJU.id, previousRiderId: null, status: 'ASSIGNED' },
    ]);

    const asAdmin = (await request(app).get(`/api/v1/admin/deliveries/orders/${orderId}`).set(owner())).body.data;
    const asRider = (await request(app).get(`/api/v1/rider/deliveries/${id}`).set(rider())).body.data;
    const asCustomer = (await request(app).get(`/api/v1/deliveries/orders/${orderId}`).set(customer())).body.data;
    expect(asAdmin.rider).toEqual({ id: RAJU.id, name: 'Raju', phone: '+919811100001' });
    expect(asRider).toMatchObject({ customer: { name: 'Alice' }, address: { landmark: 'Temple' }, note: 'Ring twice', codPaise: 34_000 });
    expect(asCustomer).toMatchObject({ status: 'ASSIGNED', rider: { name: 'Raju' }, otp: row.otp, location: null });
    expect(JSON.stringify(asAdmin) + JSON.stringify(asRider)).not.toContain(`"${row.otp}"`);
  });

  it('UPI orders have nothing to collect; riders list shows open work', async () => {
    await assigned({ paymentMethod: 'UPI' });
    expect((await deliveryOf([...orders.keys()][0]!)).codPaise).toBe(0);
    const riders = (await request(app).get('/api/v1/admin/riders').set(owner())).body.data;
    expect(riders).toEqual([
      { ...RAJU, activeDeliveries: 1 },
      { ...VIKAS, activeDeliveries: 0 },
    ]);
  });

  it('refuses pickup orders, orders not accepted or already gone, and unknown riders', async () => {
    expect((await assign(newOrder({ fulfillment: 'PICKUP', address: null }))).body.error.code).toBe('NOT_A_DELIVERY_ORDER');
    expect((await assign(newOrder({ status: 'PLACED' }))).body.error.code).toBe('DELIVERY_NOT_ASSIGNABLE');
    expect((await assign(newOrder({ status: 'OUT_FOR_DELIVERY' }))).body.error.code).toBe('DELIVERY_NOT_ASSIGNABLE');
    expect((await assign(newOrder(), B_RIDER.id)).body.error.code).toBe('RIDER_NOT_FOUND');
    expect((await assign(newOrder(), RAJU.id, sign(SHOP_A, RAJU.id, 'RIDER'))).status).toBe(403);
  });

  it('reassigning before pickup moves it to the new rider and keeps the code; not after pickup', async () => {
    const { orderId, id } = await assigned();
    const otp = (await deliveryOf(orderId)).otp;
    expect((await assign(orderId, VIKAS.id)).body.data.rider.name).toBe('Vikas');
    expect((await assign(orderId, VIKAS.id)).status).toBe(200); // same rider again: no change
    expect((await events()).at(-1)).toMatchObject({ riderId: VIKAS.id, previousRiderId: RAJU.id, status: 'ASSIGNED' });
    expect(await events()).toHaveLength(2);
    expect((await deliveryOf(orderId)).otp).toBe(otp);
    expect((await request(app).get(`/api/v1/rider/deliveries/${id}`).set(rider(RAJU))).status).toBe(404);

    await request(app).post(`/api/v1/rider/deliveries/${id}/pickup`).set(rider(VIKAS)).expect(200);
    expect((await assign(orderId, RAJU.id)).body.error.code).toBe('DELIVERY_ALREADY_STARTED');
  });
});

describe('rider flow', () => {
  it('pickup needs a packed order and takes it out for delivery as the rider', async () => {
    const { orderId, id } = await assigned({ status: 'CONFIRMED' });
    expect((await request(app).post(`/api/v1/rider/deliveries/${id}/pickup`).set(rider())).body.error.code).toBe('ORDER_NOT_PACKED');
    orders.get(orderId)!.status = 'PACKED';
    const res = await request(app).post(`/api/v1/rider/deliveries/${id}/pickup`).set(rider());
    expect(res.body.data.status).toBe('PICKED_UP');
    expect(orders.get(orderId)!.status).toBe('OUT_FOR_DELIVERY');
    expect(statusCalls.at(-1)).toEqual({ orderId, status: 'OUT_FOR_DELIVERY', role: 'RIDER' });
    // Retrying is harmless.
    expect((await request(app).post(`/api/v1/rider/deliveries/${id}/pickup`).set(rider())).body.data.status).toBe('PICKED_UP');
  });

  it('delivering needs the customer code; wrong codes count down', async () => {
    const { orderId, id } = await assigned();
    const otp = (await deliveryOf(orderId)).otp;
    const deliver = (code: string) => request(app).post(`/api/v1/rider/deliveries/${id}/deliver`).set(rider()).send({ otp: code });
    expect((await deliver(otp)).body.error.code).toBe('DELIVERY_NOT_STARTED');
    await request(app).post(`/api/v1/rider/deliveries/${id}/pickup`).set(rider()).expect(200);

    const wrong = otp === '0000' ? '1111' : '0000';
    expect((await deliver(wrong)).body.error).toMatchObject({ code: 'DELIVERY_OTP_INVALID', details: { attemptsLeft: 4 } });
    const done = await deliver(otp);
    expect(done.body.data.status).toBe('DELIVERED');
    expect(orders.get(orderId)!.status).toBe('DELIVERED');
    expect((await request(app).get(`/api/v1/deliveries/orders/${orderId}`).set(customer())).body.data.otp).toBeNull();
    expect((await events()).map((e) => e.status)).toEqual(['ASSIGNED', 'PICKED_UP', 'DELIVERED']);
  });

  it('after 5 wrong codes the rider must ask the shop', async () => {
    const { orderId, id } = await assigned();
    const otp = (await deliveryOf(orderId)).otp;
    const wrong = otp === '0000' ? '1111' : '0000';
    await request(app).post(`/api/v1/rider/deliveries/${id}/pickup`).set(rider()).expect(200);
    for (let i = 0; i < 5; i++) await request(app).post(`/api/v1/rider/deliveries/${id}/deliver`).set(rider()).send({ otp: wrong });
    const blocked = await request(app).post(`/api/v1/rider/deliveries/${id}/deliver`).set(rider()).send({ otp });
    expect(blocked.status).toBe(429);
    expect(orders.get(orderId)!.status).toBe('OUT_FOR_DELIVERY');
  });

  it('riders see only their own work, grouped active / done', async () => {
    const a = await assigned();
    await assign(newOrder(), VIKAS.id);
    const list = (await request(app).get('/api/v1/rider/deliveries').set(rider())).body.data;
    expect(list.map((d: { id: string }) => d.id)).toEqual([a.id]);
    expect((await request(app).get('/api/v1/rider/deliveries?group=done').set(rider())).body.data).toEqual([]);
    expect((await request(app).post(`/api/v1/rider/deliveries/${a.id}/pickup`).set(rider(VIKAS))).status).toBe(404);
  });
});

describe('isolation', () => {
  it("other customers and other shops see nothing; customers cannot use rider routes", async () => {
    const { orderId, id } = await assigned();
    expect((await request(app).get(`/api/v1/deliveries/orders/${orderId}`).set(customer(BOB))).status).toBe(404);
    expect((await request(app).get(`/api/v1/deliveries/orders/${orderId}`).set(customer(ALICE, SHOP_B))).status).toBe(404);
    expect((await request(app).get(`/api/v1/admin/deliveries/orders/${orderId}`).set(owner(SHOP_B))).status).toBe(404);
    expect((await assign(orderId, B_RIDER.id, owner(SHOP_B))).status).toBe(404);
    expect((await request(app).get(`/api/v1/rider/deliveries/${id}`).set(rider(RAJU, SHOP_B))).status).toBe(404);
    expect((await request(app).get('/api/v1/rider/deliveries').set(customer())).status).toBe(403);
  });
});

describe('rider location', () => {
  const report = (r: Rider = RAJU, shopId = SHOP_A) =>
    request(app).post('/internal/deliveries/location').set(rider(r, shopId)).send({ lat: 21.765, lng: 72.151, accuracy: 12 });

  it('is kept only while the rider is on the way, and goes to that order customer only', async () => {
    const { orderId, id } = await assigned();
    expect((await report()).body.data).toEqual({ targets: [], location: null });
    expect(await locations.get(SHOP_A, RAJU.id)).toBeNull();

    await request(app).post(`/api/v1/rider/deliveries/${id}/pickup`).set(rider()).expect(200);
    const res = (await report()).body.data;
    expect(res.targets).toEqual([{ orderId, customerId: ALICE }]);
    const seen = (await request(app).get(`/api/v1/deliveries/orders/${orderId}`).set(customer())).body.data.location;
    expect(seen).toMatchObject({ lat: 21.765, lng: 72.151, accuracy: 12 });
    expect((await report(RAJU, SHOP_B)).body.data.targets).toEqual([]);
    expect((await request(app).post('/internal/deliveries/location').set(customer()).send({ lat: 1, lng: 1 })).status).toBe(403);
  });
});

describe('order events', () => {
  const changed = (orderId: string, to: string, byRole = 'OWNER') =>
    buildEvent('order.status_changed', SHOP_A, {
      orderId,
      number: 1,
      customerId: ALICE,
      fulfillment: 'DELIVERY',
      from: 'PACKED',
      to: to as 'REJECTED',
      byRole,
      reason: null,
    });
  const deliver = (event: ReturnType<typeof changed>) =>
    runWithContext({ requestId: event.eventId, shopId: event.shopId }, () => orderEventsHandler(deliveries)(event));

  it('a rejected order cancels the delivery once; shop shortcuts keep it in step', async () => {
    const rejected = await assigned();
    await deliver(changed(rejected.orderId, 'REJECTED'));
    await deliver(changed(rejected.orderId, 'REJECTED'));
    expect((await deliveryOf(rejected.orderId)).status).toBe('CANCELLED');
    expect((await request(app).get(`/api/v1/deliveries/orders/${rejected.orderId}`).set(customer())).status).toBe(404);

    const shopDelivered = await assigned();
    await deliver(changed(shopDelivered.orderId, 'OUT_FOR_DELIVERY'));
    expect((await deliveryOf(shopDelivered.orderId)).status).toBe('PICKED_UP');
    await deliver(changed(shopDelivered.orderId, 'DELIVERED'));
    expect((await deliveryOf(shopDelivered.orderId)).status).toBe('DELIVERED');
    expect((await events()).map((e) => e.status)).toEqual(['ASSIGNED', 'CANCELLED', 'ASSIGNED', 'PICKED_UP', 'DELIVERED']);
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    expect(findRawPrismaOffenders(fileURLToPath(new URL('../src/', import.meta.url)))).toEqual([]);
  });
});
