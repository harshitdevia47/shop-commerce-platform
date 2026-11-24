import { createHmac, randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createLogger, findRawPrismaOffenders, getContext, signInternalHeaders, type Role } from '@qc/common';
import type { PaymentsConfig } from '@qc/config-schema';
import type { Express } from 'express';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { createPaymentApp } from '../src/app.js';
import { createDb } from '../src/db.js';
import { upiAmount } from '../src/providers/payment-provider.js';
import { buildEvent, onceOnly, prismaProcessedEvents, type AnyEvent } from '@qc/events';
import { runWithContext } from '@qc/common';
import { orderEventsHandler } from '../src/consumers/order-events.js';
import { sweepOrphanPayments } from '../src/jobs/orphan-sweeper.js';
import { createPaymentsService } from '../src/modules/payments/payments.service.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
const CUSTOMER = randomUUID();
const STRANGER = randomUUID();
const OWNER = randomUUID();

const payments: Record<string, PaymentsConfig> = {
  [SHOP_A]: { cod: true, upi: { enabled: true, vpa: 'sharma@okaxis', payeeName: 'Sharma Kirana' }, razorpay: { enabled: true } },
  [SHOP_B]: { cod: true, upi: { enabled: false }, razorpay: { enabled: false } },
};

let app: Express;
const RZP = { keyId: 'rzp_test_abc123', keySecret: 'key-secret-123', webhookSecret: 'webhook-secret-123' };
let razorpayOrders: { keyId: string; amountPaise: number; receipt: string; notes: Record<string, string> }[] = [];
let razorpayDown = false;
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
    shopConfig: { get: async () => ({ slug: getContext()!.shopId === SHOP_A ? 'shop_a' : 'shop_b', payments: payments[getContext()!.shopId!]! }) },
    razorpay: {
      accounts: { get: (slug) => (slug === 'shop_a' ? RZP : null) },
      api: {
        async createOrder(credentials, input) {
          if (razorpayDown) throw new Error('down');
          razorpayOrders.push({ keyId: credentials.keyId, ...input });
          return { id: `order_${razorpayOrders.length}` };
        },
      },
    },
  });
});
async function clean() {
  const where = { shopId: { in: [SHOP_A, SHOP_B] } };
  await rawPrisma.payment.deleteMany({ where });
  await rawPrisma.outboxEvent.deleteMany({ where });
  await rawPrisma.processedEvent.deleteMany({ where });
}
beforeEach(clean);
afterAll(async () => {
  await clean();
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

describe('events', () => {
  const service = createPaymentsService(db, { get: async () => ({ payments: payments[getContext()!.shopId!]! }) });
  const statusOf = async (orderId: string) => (await rawPrisma.payment.findFirst({ where: { orderId } }))!;
  const deliver = (event: AnyEvent, handler = orderEventsHandler(service)) =>
    runWithContext({ requestId: event.eventId, shopId: event.shopId }, () => handler(event));
  const statusChanged = (orderId: string, to: 'CANCELLED' | 'CONFIRMED', shopId = SHOP_A) =>
    buildEvent('order.status_changed', shopId, {
      orderId,
      number: 42,
      customerId: CUSTOMER,
      fulfillment: 'DELIVERY',
      from: 'PLACED',
      to,
      byRole: 'CUSTOMER',
      reason: null,
    });

  it('UTR submission and mark paid write events with the payment change', async () => {
    const { orderId } = await createPayment('UPI');
    await request(app).post(`/api/v1/payments/orders/${orderId}/utr`).set(customer()).send({ utr: '123456789012' });
    await request(app).post(`/api/v1/admin/payments/orders/${orderId}/mark-paid`).set(owner()).send({});
    const rows = await rawPrisma.outboxEvent.findMany({ where: { shopId: SHOP_A }, orderBy: { id: 'asc' } });
    expect(rows.map((r) => r.type)).toEqual(['payment.utr_submitted', 'payment.marked_paid']);
    expect(rows[1]!.envelope).toMatchObject({ payload: { orderId, orderNumber: 42, customerId: CUSTOMER, amountPaise: 12050 } });
  });

  it('a cancelled order voids its payment; other changes do not', async () => {
    const { orderId } = await createPayment('UPI');
    await deliver(statusChanged(orderId, 'CONFIRMED'));
    expect((await statusOf(orderId)).status).toBe('PENDING');
    await deliver(statusChanged(orderId, 'CANCELLED'));
    expect((await statusOf(orderId)).status).toBe('VOID');
  });

  it("events only touch their own shop's payments", async () => {
    const { orderId } = await createPayment('COD', SHOP_A);
    await deliver(statusChanged(orderId, 'CANCELLED', SHOP_B));
    expect((await statusOf(orderId)).status).toBe('PENDING');
  });

  it('order.placed confirms the payment; a duplicate event is handled once', async () => {
    const { orderId } = await createPayment('COD');
    let calls = 0;
    const counting = onceOnly(prismaProcessedEvents(db.processedEvent), async (event) => {
      calls++;
      await orderEventsHandler(service)(event);
    });
    const placed = buildEvent('order.placed', SHOP_A, {
      orderId,
      number: 42,
      customerId: CUSTOMER,
      totalPaise: 12050,
      itemCount: 1,
      fulfillment: 'PICKUP',
      paymentMethod: 'COD',
    });
    await deliver(placed, counting);
    await deliver(placed, counting);
    expect(calls).toBe(1);
    expect((await statusOf(orderId)).orderConfirmedAt).not.toBeNull();
  });

  it('the sweeper voids payments whose order never got created and confirms the rest', async () => {
    const real = await createPayment('COD');
    const orphan = await createPayment('UPI');
    const other = await createPayment('COD', SHOP_B);
    const askedBy: string[] = [];
    const result = await sweepOrphanPayments(
      async () => [real, orphan, other].map(({ orderId }) => ({ orderId, shopId: orderId === other.orderId ? SHOP_B : SHOP_A })),
      {
        existing: async (ids) => {
          askedBy.push(getContext()!.shopId!);
          return ids.filter((id) => id === real.orderId || id === other.orderId);
        },
      },
      service,
      createLogger('sweeper-test', 'silent'),
    );
    expect(result).toEqual({ confirmed: 2, voided: 1 });
    expect(askedBy.sort()).toEqual([SHOP_A, SHOP_B].sort());
    expect((await statusOf(orphan.orderId)).status).toBe('VOID');
    expect((await statusOf(real.orderId)).status).toBe('PENDING');
    expect((await statusOf(real.orderId)).orderConfirmedAt).not.toBeNull();
  });
});

describe('Razorpay', () => {
  const sign = (secret: string, payload: string) => createHmac('sha256', secret).update(payload).digest('hex');
  beforeEach(() => {
    razorpayOrders = [];
    razorpayDown = false;
  });

  it('creates a Razorpay order with the payment and gives the app what Checkout needs', async () => {
    const { orderId, res } = await createPayment('RAZORPAY' as 'UPI');
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(razorpayOrders).toEqual([{ keyId: 'rzp_test_abc123', amountPaise: 12050, receipt: 'Order #42', notes: { orderId, shopId: SHOP_A } }]);
    expect(res.body.data).toMatchObject({ method: 'RAZORPAY', status: 'PENDING', razorpay: { keyId: 'rzp_test_abc123', orderId: 'order_1', amountPaise: 12050 } });
    expect(JSON.stringify(res.body)).not.toContain('key-secret');
  });

  it('marks paid only with a valid checkout signature from the order owner', async () => {
    const { orderId } = await createPayment('RAZORPAY' as 'UPI');
    const confirm = (signature: string, headers = customer()) =>
      request(app)
        .post(`/api/v1/payments/orders/${orderId}/razorpay`)
        .set(headers)
        .send({ razorpayOrderId: 'order_1', razorpayPaymentId: 'pay_9', razorpaySignature: signature });
    expect((await confirm(sign('wrong-secret', 'order_1|pay_9'))).body.error.code).toBe('PAYMENT_SIGNATURE_INVALID');
    expect((await confirm(sign(RZP.keySecret, 'order_1|pay_9'), customer(SHOP_A, STRANGER))).status).toBe(404);
    const ok = await confirm(sign(RZP.keySecret, 'order_1|pay_9'));
    expect(ok.body.data).toMatchObject({ status: 'PAID' });
    expect(ok.body.data.razorpay).toBeUndefined();
    const events = await rawPrisma.outboxEvent.findMany({ where: { shopId: SHOP_A, type: 'payment.marked_paid' } });
    expect(events).toHaveLength(1);
  });

  it('the webhook confirms a payment the app never reported, once, and rejects bad signatures', async () => {
    const { orderId } = await createPayment('RAZORPAY' as 'UPI');
    const body = JSON.stringify({ event: 'payment.captured', payload: { payment: { entity: { id: 'pay_7', order_id: 'order_1', status: 'captured' } } } });
    const hook = (signature: string) =>
      request(app)
        .post('/api/v1/webhooks/razorpay/shop_a')
        .set(svc())
        .set('content-type', 'application/json')
        .set('x-razorpay-signature', signature)
        .send(body);
    expect((await hook(sign('nope-nope-nope', body))).body.error.code).toBe('WEBHOOK_SIGNATURE_INVALID');
    expect((await hook(sign(RZP.webhookSecret, body))).body.data).toEqual({ handled: true });
    expect((await hook(sign(RZP.webhookSecret, body))).body.data).toEqual({ handled: false });
    const payment = await rawPrisma.payment.findFirstOrThrow({ where: { orderId } });
    expect(payment).toMatchObject({ status: 'PAID', providerPaymentId: 'pay_7' });
  });

  it('is refused when the shop has no account or Razorpay is down', async () => {
    expect((await createPayment('RAZORPAY' as 'UPI', SHOP_B)).res.body.error.code).toBe('PAYMENT_METHOD_UNAVAILABLE');
    razorpayDown = true;
    expect((await createPayment('RAZORPAY' as 'UPI')).res.body.error.code).toBe('PAYMENT_PROVIDER_UNAVAILABLE');
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    expect(findRawPrismaOffenders(fileURLToPath(new URL('../src/', import.meta.url)))).toEqual([]);
  });
});
