import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createLogger, findRawPrismaOffenders, runWithContext } from '@qc/common';
import { PRESETS, type RuntimeConfig } from '@qc/config-schema';
import { buildEvent, onceOnly, prismaProcessedEvents, type AnyEvent } from '@qc/events';
import { exportPKCS8, generateKeyPair } from 'jose';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createDb } from '../src/db.js';
import { formatRupees } from '../src/messages.js';
import { createNotifier, type DeviceDirectory, type PushTarget } from '../src/notifier.js';
import { fcmPushSender, type PushMessage, type PushSender } from '../src/push/push-sender.js';

const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const logger = createLogger('notification-test', 'silent');
const SHOP = randomUUID();
const CUSTOMER = randomUUID();
const ORDER = randomUUID();
const DELIVERY = randomUUID();
const RIDER_NEW = randomUUID();
const RIDER_OLD = randomUUID();

const config: RuntimeConfig = {
  shop: {
    name: 'Sharma Kirana',
    nameI18n: { gu: 'શર્મા કિરાણા' },
    businessType: 'grocery',
    currency: 'INR',
    timezone: 'Asia/Kolkata',
    contact: { phone: '+919876543210', address: 'x', lat: 21.7, lng: 72.1 },
  },
  delivery: { enabled: true, radiusKm: 5, pincodes: [], minOrderPaise: 0, feePaise: 0, freeAbovePaise: null, etaMinutes: 30 },
  payments: { cod: true, upi: { enabled: false }, razorpay: { enabled: false } },
  features: PRESETS.grocery.features,
  catalog: PRESETS.grocery.catalog,
} as RuntimeConfig;

let devices: PushTarget[];
let removed: string[];
let sent: PushMessage[];
let invalid: string[];

const directory: DeviceDirectory = {
  async targets(query) {
    return devices.filter((d) =>
      'admins' in query && query.admins ? d.userId.startsWith('admin') : (query.userIds ?? []).includes(d.userId),
    );
  },
  async remove(tokens) {
    removed.push(...tokens);
  },
};
const push: PushSender = {
  name: 'fake',
  async send(messages) {
    sent.push(...messages);
    return { sent: messages.length, invalidTokens: messages.map((m) => m.token).filter((t) => invalid.includes(t)) };
  },
};
const notifier = createNotifier({ shopConfig: { get: async () => config }, devices: directory, push, logger });
const deliver = (event: AnyEvent, handler = notifier) =>
  runWithContext({ requestId: event.eventId, shopId: event.shopId }, () => handler(event));

const placed = () =>
  buildEvent('order.placed', SHOP, {
    orderId: ORDER,
    number: 12,
    customerId: CUSTOMER,
    totalPaise: 34_050,
    itemCount: 3,
    fulfillment: 'DELIVERY',
    paymentMethod: 'UPI',
  });
const changed = (to: 'CONFIRMED' | 'REJECTED' | 'CANCELLED' | 'PLACED', reason: string | null = null) =>
  buildEvent('order.status_changed', SHOP, {
    orderId: ORDER,
    number: 12,
    customerId: CUSTOMER,
    fulfillment: 'DELIVERY',
    from: 'PLACED',
    to,
    byRole: to === 'CANCELLED' ? 'CUSTOMER' : 'OWNER',
    reason,
  });

beforeEach(async () => {
  devices = [
    { userId: CUSTOMER, token: 'customer-gu', platform: 'android', locale: 'gu' },
    { userId: 'admin-1', token: 'owner-en', platform: 'android', locale: 'en' },
    { userId: 'admin-2', token: 'staff-hi', platform: 'android', locale: 'hi' },
  ];
  removed = [];
  sent = [];
  invalid = [];
  await rawPrisma.processedEvent.deleteMany({ where: { shopId: SHOP } });
});

afterAll(async () => {
  await rawPrisma.processedEvent.deleteMany({ where: { shopId: SHOP } });
  await rawPrisma.$disconnect();
});

describe('who gets what', () => {
  it('a new order goes to owner and staff, each in their phone language', async () => {
    await deliver(placed());
    expect(sent.map((m) => [m.token, m.title, m.body])).toEqual([
      ['owner-en', 'New order #12', '₹340.50 · 3 items · Delivery · UPI'],
      ['staff-hi', 'नया ऑर्डर #12', '₹340.50 · 3 आइटम · डिलीवरी · UPI'],
    ]);
    expect(sent[0]).toMatchObject({
      channelId: 'orders',
      tag: ORDER,
      data: { type: 'order.placed', orderId: ORDER, route: `/admin/orders/${ORDER}` },
    });
  });

  it('status updates go to the customer with the localized shop name', async () => {
    await deliver(changed('CONFIRMED'));
    expect(sent).toHaveLength(1);
    expect(sent[0]).toMatchObject({
      token: 'customer-gu',
      title: 'ઓર્ડર #12 સ્વીકારાયો',
      body: 'શર્મા કિરાણા તમારો ઓર્ડર તૈયાર કરી રહ્યું છે.',
      data: { route: `/orders/${ORDER}` },
    });
  });

  it("a rejection carries the shop's reason, or a default", async () => {
    devices[0]!.locale = 'en';
    await deliver(changed('REJECTED', 'Closed for Diwali'));
    await deliver(changed('REJECTED'));
    expect(sent.map((m) => m.body)).toEqual(['Sharma Kirana: Closed for Diwali', 'Sharma Kirana: The shop could not take this order.']);
  });

  it('customer cancellations go to the shop; nothing for statuses customers do not need', async () => {
    await deliver(changed('CANCELLED'));
    expect(sent.map((m) => m.token)).toEqual(['owner-en', 'staff-hi']);
    sent = [];
    await deliver(changed('PLACED'));
    expect(sent).toEqual([]);
  });

  it('UPI: shop hears about the UTR, customer about the confirmation', async () => {
    const payload = { orderId: ORDER, orderNumber: 12, customerId: CUSTOMER, amountPaise: 34_000 };
    await deliver(buildEvent('payment.utr_submitted', SHOP, payload));
    await deliver(buildEvent('payment.marked_paid', SHOP, payload));
    expect(sent.map((m) => [m.token, m.title])).toEqual([
      ['owner-en', 'UPI payment for #12'],
      ['staff-hi', '#12 के लिए UPI भुगतान'],
      ['customer-gu', '#12 ની ચુકવણી મળી'],
    ]);
  });

  it('drops tokens the push service reports as gone', async () => {
    invalid = ['staff-hi'];
    await deliver(placed());
    expect(removed).toEqual(['staff-hi']);
  });

  it('a duplicate event never pushes twice', async () => {
    const once = onceOnly(prismaProcessedEvents(db.processedEvent), notifier);
    const event = placed();
    await deliver(event, once);
    await deliver(event, once);
    expect(sent).toHaveLength(2);
  });

  it('riders hear about new, reassigned and cancelled deliveries in their language', async () => {
    devices.push(
      { userId: RIDER_NEW, token: 'rider-new-hi', platform: 'android', locale: 'hi' },
      { userId: RIDER_OLD, token: 'rider-old-en', platform: 'android', locale: 'en' },
    );
    const delivery = (status: 'ASSIGNED' | 'CANCELLED' | 'PICKED_UP', previousRiderId: string | null = null) =>
      buildEvent('delivery.status_changed', SHOP, {
        deliveryId: DELIVERY,
        orderId: ORDER,
        number: 12,
        customerId: CUSTOMER,
        riderId: RIDER_NEW,
        previousRiderId,
        status,
      });
    await deliver(delivery('ASSIGNED', RIDER_OLD));
    await deliver(delivery('PICKED_UP'));
    await deliver(delivery('CANCELLED'));
    expect(sent.map((m) => [m.token, m.title, m.data.route])).toEqual([
      ['rider-new-hi', 'नई डिलीवरी #12', `/rider/deliveries/${DELIVERY}`],
      ['rider-old-en', 'Delivery #12 reassigned', '/rider'],
      ['rider-new-hi', 'डिलीवरी #12 रद्द', `/rider/deliveries/${DELIVERY}`],
    ]);
  });

  it('formats rupees with Indian grouping', () => {
    expect(formatRupees(12_345_600)).toBe('₹1,23,456');
    expect(formatRupees(5)).toBe('₹0.05');
  });
});

describe('FCM HTTP v1 sender', () => {
  async function account() {
    const { privateKey } = await generateKeyPair('RS256', { extractable: true });
    return JSON.stringify({ project_id: 'qc-test', client_email: 'push@qc-test.iam.gserviceaccount.com', private_key: await exportPKCS8(privateKey) });
  }
  const message = (token: string): PushMessage => ({ token, title: 't', body: 'b', data: { route: '/orders/x' }, channelId: 'orders', tag: 'x' });

  it('authenticates once, sends each message, reports dead tokens', async () => {
    const calls: { url: string; body: string }[] = [];
    const fakeFetch = (async (url: string, init: RequestInit) => {
      calls.push({ url, body: String(init.body) });
      if (url.includes('oauth2')) return Response.json({ access_token: 'oauth-token', expires_in: 3600 });
      const sentTo = JSON.parse(String(init.body)).message.token as string;
      if (sentTo === 'gone') return Response.json({ error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }, { status: 404 });
      return Response.json({ name: 'projects/qc-test/messages/1' });
    }) as typeof fetch;

    const sender = fcmPushSender(await account(), logger, fakeFetch);
    const first = await sender.send([message('ok'), message('gone')]);
    await sender.send([message('ok')]);

    expect(first).toEqual({ sent: 1, invalidTokens: ['gone'] });
    expect(calls.filter((c) => c.url.includes('oauth2'))).toHaveLength(1);
    const sends = calls.filter((c) => c.url === 'https://fcm.googleapis.com/v1/projects/qc-test/messages:send');
    expect(sends).toHaveLength(3);
    expect(JSON.parse(sends[0]!.body).message).toMatchObject({
      token: 'ok',
      notification: { title: 't', body: 'b' },
      android: { priority: 'HIGH', notification: { channel_id: 'orders', tag: 'x' } },
    });
  });

  it('throws (so the event is retried) only when FCM is down for every message', async () => {
    const fakeFetch = (async (url: string) =>
      url.includes('oauth2') ? Response.json({ access_token: 'a', expires_in: 3600 }) : new Response('down', { status: 503 })) as typeof fetch;
    const sender = fcmPushSender(await account(), logger, fakeFetch);
    await expect(sender.send([message('a'), message('b')])).rejects.toThrow('FCM unavailable');
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    expect(findRawPrismaOffenders(fileURLToPath(new URL('../src/', import.meta.url)))).toEqual([]);
  });
});
