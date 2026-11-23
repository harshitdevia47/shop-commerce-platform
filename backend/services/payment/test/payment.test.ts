import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createLogger, findRawPrismaOffenders, getContext, signInternalHeaders, type Role } from '@qc/common';
import type { PaymentsConfig } from '@qc/config-schema';
import type { Express } from 'express';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { createPaymentApp } from '../src/app.js';
import { createDb } from '../src/db.js';
import { upiAmount } from '../src/providers/payment-provider.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
const CUSTOMER = randomUUID();
const STRANGER = randomUUID();
const OWNER = randomUUID();

const payments: Record<string, PaymentsConfig> = {
  [SHOP_A]: { cod: true, upi: { enabled: true, vpa: 'sharma@okaxis', payeeName: 'Sharma Kirana' }, razorpay: { enabled: false } },
  [SHOP_B]: { cod: true, upi: { enabled: false }, razorpay: { enabled: false } },
};

let app: Express;
const sign = (shopId: string, userId?: string, role?: Role) =>
  signInternalHeaders({ requestId: randomUUID(), shopId, userId, role }, SECRET);
const svc = (shopId: string = SHOP_A) => sign(shopId);
const customer = (shopId: string = SHOP_A, userId = CUSTOMER) => sign(shopId, userId, 'CUSTOMER');
const owner = (shopId: string = SHOP_A) => sign(shopId, OWNER, 'OWNER');

async function createPayment(method: 'COD' | 'UPI', shopId: string = SHOP_A, amountPaise = 12050) {
  const orderId = randomUUID();
  const res = await request(app)
    .post('/internal/payments')
    .set(svc(shopId))
    .send({ orderId, orderNumber: 42, customerId: CUSTOMER, method, amountPaise });
  return { orderId, res };
}

beforeAll(() => {
  app = createPaymentApp({
    db,
    logger: createLogger('payment-test', 'silent'),
    internalSecret: SECRET,
    shopConfig: { get: async () => ({ payments: payments[getContext()!.shopId!]! }) },
  });
});
beforeEach(async () => {
  await rawPrisma.payment.deleteMany({ where: { shopId: { in: [SHOP_A, SHOP_B] } } });
});
afterAll(async () => {
  await rawPrisma.payment.deleteMany({ where: { shopId: { in: [SHOP_A, SHOP_B] } } });
  await rawPrisma.$disconnect();
});

describe('create (order saga)', () => {
  it('UPI payment carries an intent link with amount and order number', async () => {
    const { res } = await createPayment('UPI');
    expect(res.status).toBe(201);
    expect(res.body.data).toMatchObject({ method: 'UPI', status: 'PENDING', amountPaise: 12050 });
    expect(res.body.data.upiUri).toMatch(/^upi:\/\/pay\?pa=sharma@okaxis&pn=Sharma%20Kirana&/);
    const uri = new URL(res.body.data.upiUri);
    expect(uri.protocol).toBe('upi:');
    expect(Object.fromEntries(uri.searchParams)).toMatchObject({
      pa: 'sharma@okaxis',
      pn: 'Sharma Kirana',
      am: '120.50',
      cu: 'INR',
      tn: 'Order #42',
    });
  });

  it('COD has no link; idempotent per order', async () => {
    const { orderId, res } = await createPayment('COD');
    expect(res.body.data.upiUri).toBeUndefined();
    const again = await request(app)
      .post('/internal/payments')
      .set(svc())
      .send({ orderId, orderNumber: 42, customerId: CUSTOMER, method: 'COD', amountPaise: 12050 });
    expect(again.body.data.id).toBe(res.body.data.id);
  });

  it('refuses a method the shop has switched off', async () => {
    const { res } = await createPayment('UPI', SHOP_B);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('PAYMENT_METHOD_UNAVAILABLE');
  });

  it('formats UPI amounts', () => {
    expect([upiAmount(12050), upiAmount(100), upiAmount(5), upiAmount(123456789)]).toEqual(['120.50', '1.00', '0.05', '1234567.89']);
  });
});

describe('customer and owner flow', () => {
  it('customer submits a UTR; owner marks paid; link disappears', async () => {
    const { orderId } = await createPayment('UPI');
    const submitted = await request(app).post(`/api/v1/payments/orders/${orderId}/utr`).set(customer()).send({ utr: '412345678901' });
    expect(submitted.body.data).toMatchObject({ status: 'SUBMITTED', utr: '412345678901' });

    const waiting = await request(app).get('/api/v1/admin/payments?status=SUBMITTED').set(owner());
    expect(waiting.body.data.map((p: { orderId: string }) => p.orderId)).toEqual([orderId]);

    const paid = await request(app).post(`/api/v1/admin/payments/orders/${orderId}/mark-paid`).set(owner());
    expect(paid.body.data).toMatchObject({ status: 'PAID' });
    expect(paid.body.data.upiUri).toBeUndefined();
    expect(paid.body.data.paidAt).toBeTruthy();

    const late = await request(app).post(`/api/v1/payments/orders/${orderId}/utr`).set(customer()).send({ utr: '412345678902' });
    expect(late.body.error.code).toBe('PAYMENT_CLOSED');
  });

  it('validates UTR and method', async () => {
    const upi = await createPayment('UPI');
    const bad = await request(app).post(`/api/v1/payments/orders/${upi.orderId}/utr`).set(customer()).send({ utr: '12' });
    expect(bad.status).toBe(400);
    const cod = await createPayment('COD');
    const notUpi = await request(app).post(`/api/v1/payments/orders/${cod.orderId}/utr`).set(customer()).send({ utr: '412345678901' });
    expect(notUpi.body.error.code).toBe('PAYMENT_NOT_UPI');
  });

  it('void cancels unpaid payments only', async () => {
    const pending = await createPayment('COD');
    const voided = await request(app).post('/internal/payments/void').set(svc()).send({ orderId: pending.orderId });
    expect(voided.body.data.status).toBe('VOID');
    const paidAfterVoid = await request(app).post(`/api/v1/admin/payments/orders/${pending.orderId}/mark-paid`).set(owner());
    expect(paidAfterVoid.body.error.code).toBe('PAYMENT_CLOSED');

    const paid = await createPayment('COD');
    await request(app).post(`/api/v1/admin/payments/orders/${paid.orderId}/mark-paid`).set(owner()).expect(200);
    const kept = await request(app).post('/internal/payments/void').set(svc()).send({ orderId: paid.orderId });
    expect(kept.body.data.status).toBe('PAID');
  });

  it('only admins mark paid', async () => {
    const { orderId } = await createPayment('COD');
    const res = await request(app).post(`/api/v1/admin/payments/orders/${orderId}/mark-paid`).set(customer());
    expect(res.status).toBe(403);
  });
});

describe('isolation', () => {
  it("another customer of the same shop cannot see or touch the payment", async () => {
    const { orderId } = await createPayment('UPI');
    expect((await request(app).get(`/api/v1/payments/orders/${orderId}`).set(customer(SHOP_A, STRANGER))).status).toBe(404);
    expect(
      (await request(app).post(`/api/v1/payments/orders/${orderId}/utr`).set(customer(SHOP_A, STRANGER)).send({ utr: '412345678901' })).status,
    ).toBe(404);
    expect((await request(app).get(`/api/v1/payments/orders/${orderId}`).set(customer())).status).toBe(200);
  });

  it("shop B's owner cannot see or mark shop A's payment", async () => {
    const { orderId } = await createPayment('COD');
    expect((await request(app).get(`/api/v1/payments/orders/${orderId}`).set(owner(SHOP_B))).status).toBe(404);
    expect((await request(app).post(`/api/v1/admin/payments/orders/${orderId}/mark-paid`).set(owner(SHOP_B))).status).toBe(404);
    expect((await request(app).get('/api/v1/admin/payments').set(owner(SHOP_B))).body.data).toEqual([]);
    expect((await request(app).post('/internal/payments/void').set(svc(SHOP_B)).send({ orderId })).body.data.status).toBeNull();
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    expect(findRawPrismaOffenders(fileURLToPath(new URL('../src/', import.meta.url)))).toEqual([]);
  });
});
