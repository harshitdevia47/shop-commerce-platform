import { randomUUID } from 'node:crypto';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MemoryRateLimitStore, createLogger, signInternalHeaders, type Role } from '@qc/common';
import type { Express } from 'express';
import { exportPKCS8, exportSPKI, generateKeyPair, jwtVerify, importSPKI } from 'jose';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { createIdentityApp } from '../src/app.js';
import { createDb } from '../src/db.js';
import { normalizeIndianMobile } from '../src/modules/auth/phone.js';
import type { OtpMessage, SmsProvider } from '../src/sms/sms-provider.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const ISSUER = 'qc-identity';
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);

class CapturingSms implements SmsProvider {
  readonly name = 'capture';
  readonly channel = 'whatsapp' as const;
  sent: OtpMessage[] = [];
  lastLocale(): string | undefined {
    return this.sent.at(-1)?.locale;
  }
  fail = false;
  async sendOtp(message: OtpMessage): Promise<void> {
    if (this.fail) throw new Error('provider down');
    this.sent.push(message);
  }
  last(): string {
    return this.sent.at(-1)!.code;
  }
}

let clock: Date;
/** Unfinished orders per user, as the order service would answer. */
let openOrders: Map<string, number>;
let sms: CapturingSms;
let app: Express;
let publicKeyPem: string;
let privateKeyPem: string;

const SHOP_A = randomUUID();
const SHOP_B = randomUUID();
const PHONE = '+919876543210';

let ipCounter = 0;
/** Simulates the gateway: signed shop/user/ip headers. Each call gets a fresh IP unless given. */
function as(shopId: string, extra: { userId?: string; role?: Role; clientIp?: string } = {}) {
  return signInternalHeaders(
    { requestId: randomUUID(), shopId, clientIp: extra.clientIp ?? `10.0.0.${++ipCounter % 250}`, ...extra },
    SECRET,
  );
}

async function build(devEcho = false): Promise<Express> {
  return createIdentityApp({
    db,
    logger: createLogger('identity-test', 'silent'),
    internalSecret: SECRET,
    sms,
    orders: { countFor: async (userId) => openOrders.get(userId) ?? 0 },
    limits: new MemoryRateLimitStore(() => clock.getTime()),
    otpSecret: 'test-otp-secret-test-otp-secret-0123456789',
    otpDevEcho: devEcho,
    jwt: { privateKeyPem, issuer: ISSUER, accessTtlSeconds: 900, refreshTtlDays: 30 },
    now: () => clock,
  });
}

async function login(shopId = SHOP_A, phone = PHONE) {
  await request(app).post('/api/v1/auth/otp/request').set(as(shopId)).send({ phone }).expect(200);
  const res = await request(app)
    .post('/api/v1/auth/otp/verify')
    .set(as(shopId))
    .send({ phone, code: sms.last() })
    .expect(200);
  return res.body.data as {
    accessToken: string;
    refreshToken: string;
    user: { id: string; role: Role; phone: string };
    isNewUser: boolean;
  };
}

beforeAll(async () => {
  const keys = await generateKeyPair('RS256', { extractable: true });
  privateKeyPem = await exportPKCS8(keys.privateKey);
  publicKeyPem = await exportSPKI(keys.publicKey);
});

beforeEach(async () => {
  clock = new Date('2026-11-23T10:00:00Z');
  sms = new CapturingSms();
  openOrders = new Map();
  app = await build();
  await rawPrisma.refreshToken.deleteMany();
  await rawPrisma.otpChallenge.deleteMany();
  await rawPrisma.address.deleteMany();
  await rawPrisma.user.deleteMany();
});

afterAll(async () => {
  await rawPrisma.$disconnect();
});

describe('phone normalisation', () => {
  it.each([
    ['9876543210', '+919876543210'],
    ['98765 43210', '+919876543210'],
    ['09876543210', '+919876543210'],
    ['919876543210', '+919876543210'],
    ['+91-98765-43210', '+919876543210'],
  ])('%s -> %s', (input, expected) => expect(normalizeIndianMobile(input)).toBe(expected));

  it.each(['12345', '5876543210', '+14155550123', 'abcdefghij'])('rejects %s', (input) =>
    expect(normalizeIndianMobile(input)).toBeNull(),
  );
});

describe('OTP login', () => {
  it('logs in a new customer and returns a verifiable RS256 access token', async () => {
    const session = await login();
    expect(session.isNewUser).toBe(true);
    expect(session.user).toMatchObject({ phone: PHONE, role: 'CUSTOMER' });

    const key = await importSPKI(publicKeyPem, 'RS256');
    const { payload } = await jwtVerify(session.accessToken, key, { issuer: ISSUER, currentDate: clock });
    expect(payload).toMatchObject({ sub: session.user.id, shopId: SHOP_A, role: 'CUSTOMER', typ: 'access' });
    expect(payload.exp! - payload.iat!).toBe(900);
  });

  it('returns the same user on the next login', async () => {
    const first = await login();
    clock = new Date(clock.getTime() + 60_000);
    const second = await login();
    expect(second.user.id).toBe(first.user.id);
    expect(second.isNewUser).toBe(false);
  });

  it('accepts local number formats', async () => {
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: '98765 43210' }).expect(200);
    expect(sms.sent[0]!.phone).toBe(PHONE);
  });

  it('rejects invalid phone numbers', async () => {
    const res = await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: '12345' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
  });

  it('never stores the code in plain text and never echoes it by default', async () => {
    const res = await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    expect(res.body.data).toEqual({ expiresInSeconds: 300, resendAfterSeconds: 30, channel: 'whatsapp' });
    const row = await rawPrisma.otpChallenge.findFirstOrThrow();
    expect(row.codeHash).not.toContain(sms.last());
    expect(row.codeHash).toHaveLength(64);
  });

  it('echoes the code only in dev-echo mode', async () => {
    app = await build(true);
    const res = await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    expect(res.body.data.debugCode).toBe(sms.last());
  });

  it('rejects a wrong code and reports attempts left', async () => {
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    const wrong = sms.last() === '000000' ? '111111' : '000000';
    const res = await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_A)).send({ phone: PHONE, code: wrong });
    expect(res.status).toBe(400);
    expect(res.body.error).toMatchObject({ code: 'OTP_INVALID', details: { attemptsLeft: 4 } });
  });

  it('locks the code after 5 wrong attempts, even if the 6th is correct', async () => {
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    const correct = sms.last();
    const wrong = correct === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) {
      await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_A)).send({ phone: PHONE, code: wrong }).expect(400);
    }
    const res = await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_A)).send({ phone: PHONE, code: correct });
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('OTP_TOO_MANY_ATTEMPTS');
  });

  it('expires codes after 5 minutes', async () => {
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    clock = new Date(clock.getTime() + 5 * 60_000 + 1);
    const res = await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_A)).send({ phone: PHONE, code: sms.last() });
    expect(res.body.error.code).toBe('OTP_EXPIRED');
  });

  it('codes are single use', async () => {
    await login();
    const res = await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_A)).send({ phone: PHONE, code: sms.last() });
    expect(res.body.error.code).toBe('OTP_EXPIRED');
  });

  it('only the newest code is valid', async () => {
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    const old = sms.last();
    clock = new Date(clock.getTime() + 31_000);
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    if (old !== sms.last()) {
      const res = await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_A)).send({ phone: PHONE, code: old });
      expect(res.body.error.code).toBe('OTP_INVALID');
    }
    await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_A)).send({ phone: PHONE, code: sms.last() }).expect(200);
  });

  it('enforces a 30 second resend cooldown', async () => {
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE }).expect(200);
    const res = await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('OTP_RESEND_TOO_SOON');
    clock = new Date(clock.getTime() + 31_000);
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE }).expect(200);
  });

  it('limits codes per phone per hour', async () => {
    for (let i = 0; i < 5; i++) {
      await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE }).expect(200);
      clock = new Date(clock.getTime() + 31_000);
    }
    const res = await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    expect(res.body.error.code).toBe('OTP_TOO_MANY_REQUESTS');
  });

  it('limits codes per client IP per hour across phones', async () => {
    for (let i = 0; i < 20; i++) {
      const phone = `+9198765432${String(i).padStart(2, '0')}`;
      await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A, { clientIp: '1.2.3.4' })).send({ phone }).expect(200);
    }
    const res = await request(app)
      .post('/api/v1/auth/otp/request')
      .set(as(SHOP_A, { clientIp: '1.2.3.4' }))
      .send({ phone: '+919999999999' });
    expect(res.body.error.code).toBe('OTP_TOO_MANY_REQUESTS');
  });

  it('returns 503 and invalidates the code when SMS fails', async () => {
    sms.fail = true;
    const res = await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('SMS_SEND_FAILED');
    expect(await rawPrisma.otpChallenge.count({ where: { expiresAt: { gt: clock } } })).toBe(0);
  });

  it('refuses blocked users', async () => {
    const session = await login();
    await rawPrisma.user.update({ where: { id: session.user.id }, data: { isBlocked: true } });
    clock = new Date(clock.getTime() + 31_000);
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    const res = await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_A)).send({ phone: PHONE, code: sms.last() });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('USER_BLOCKED');
  });
});

describe('refresh tokens', () => {
  it('rotates: new pair works, old token is rejected and kills the session', async () => {
    const session = await login();
    const first = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: session.refreshToken });
    expect(first.status).toBe(200);
    const rotated = first.body.data.refreshToken as string;
    expect(rotated).not.toBe(session.refreshToken);

    // Replaying the old token = theft signal: whole family revoked.
    const replay = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: session.refreshToken });
    expect(replay.status).toBe(401);
    expect(replay.body.error.code).toBe('REFRESH_TOKEN_REUSED');

    const afterReuse = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: rotated });
    expect(afterReuse.status).toBe(401);
  });

  it('picks up role changes on refresh', async () => {
    const session = await login();
    await rawPrisma.user.update({ where: { id: session.user.id }, data: { role: 'OWNER' } });
    const res = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: session.refreshToken });
    expect(res.body.data.user.role).toBe('OWNER');
  });

  it('expires after 30 days', async () => {
    const session = await login();
    clock = new Date(clock.getTime() + 31 * 86_400_000);
    const res = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: session.refreshToken });
    expect(res.body.error.code).toBe('REFRESH_TOKEN_EXPIRED');
  });

  it('rejects unknown tokens', async () => {
    const res = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: 'x'.repeat(43) });
    expect(res.body.error.code).toBe('REFRESH_TOKEN_INVALID');
  });

  it('logout revokes the session and is silent for unknown tokens', async () => {
    const session = await login();
    await request(app).post('/api/v1/auth/logout').set(as(SHOP_A)).send({ refreshToken: session.refreshToken }).expect(204);
    const res = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: session.refreshToken });
    expect(res.status).toBe(401);
    await request(app).post('/api/v1/auth/logout').set(as(SHOP_A)).send({ refreshToken: 'y'.repeat(43) }).expect(204);
  });

  it('blocks refresh for blocked users', async () => {
    const session = await login();
    await rawPrisma.user.update({ where: { id: session.user.id }, data: { isBlocked: true } });
    const res = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: session.refreshToken });
    expect(res.status).toBe(403);
  });
});

describe('/api/v1/me', () => {
  it('requires a user', async () => {
    const res = await request(app).get('/api/v1/me').set(as(SHOP_A));
    expect(res.status).toBe(401);
  });

  it('returns and updates the profile', async () => {
    const session = await login();
    const headers = () => as(SHOP_A, { userId: session.user.id, role: 'CUSTOMER' });
    const me = await request(app).get('/api/v1/me').set(headers());
    expect(me.body.data).toMatchObject({ id: session.user.id, phone: PHONE, name: null });

    const updated = await request(app).patch('/api/v1/me').set(headers()).send({ name: '  Ramesh  ', locale: 'gu' });
    expect(updated.body.data).toMatchObject({ name: 'Ramesh', locale: 'gu' });
  });

  it('cannot change role or phone through the profile', async () => {
    const session = await login();
    const res = await request(app)
      .patch('/api/v1/me')
      .set(as(SHOP_A, { userId: session.user.id, role: 'CUSTOMER' }))
      .send({ role: 'OWNER' });
    expect(res.status).toBe(400);
  });
});

describe('tenant isolation', () => {
  it('same phone at two shops = two separate users', async () => {
    const a = await login(SHOP_A);
    const b = await login(SHOP_B);
    expect(a.user.id).not.toBe(b.user.id);
    expect(b.isNewUser).toBe(true);
  });

  it("an OTP sent for shop A cannot log in to shop B", async () => {
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE });
    const res = await request(app).post('/api/v1/auth/otp/verify').set(as(SHOP_B)).send({ phone: PHONE, code: sms.last() });
    expect(res.body.error.code).toBe('OTP_EXPIRED');
  });

  it("shop A's refresh token is unknown at shop B", async () => {
    const session = await login(SHOP_A);
    const res = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_B)).send({ refreshToken: session.refreshToken });
    expect(res.body.error.code).toBe('REFRESH_TOKEN_INVALID');
    // and it still works at shop A (not revoked by the foreign attempt)
    await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: session.refreshToken }).expect(200);
  });

  it("a user id from shop A is not found at shop B", async () => {
    const session = await login(SHOP_A);
    const res = await request(app).get('/api/v1/me').set(as(SHOP_B, { userId: session.user.id, role: 'CUSTOMER' }));
    expect(res.status).toBe(404);
  });
});

describe('/api/v1/me/addresses', () => {
  const home = { line1: '12 Station Road', city: 'Bhavnagar', pincode: '364001', landmark: 'Near temple' };

  let userId: string | undefined;
  /** Logs in once per test (OTP cooldown), then signs fresh headers for that user. */
  async function customer(shopId = SHOP_A) {
    userId ??= (await login(shopId)).user.id;
    return as(shopId, { userId, role: 'CUSTOMER' });
  }
  beforeEach(() => {
    userId = undefined;
  });

  it('first address becomes the default; a new default replaces it', async () => {
    const headers = await customer();
    const first = await request(app).post('/api/v1/me/addresses').set(headers).send(home);
    expect(first.status).toBe(201);
    expect(first.body.data).toMatchObject({ ...home, label: 'home', isDefault: true });
    expect(first.body.data).not.toHaveProperty('shopId');

    const work = await request(app)
      .post('/api/v1/me/addresses')
      .set(await customer())
      .send({ ...home, label: 'work', line1: 'GIDC', isDefault: true });
    const list = await request(app).get('/api/v1/me/addresses').set(await customer());
    expect(list.body.data.map((a: { id: string; isDefault: boolean }) => [a.id, a.isDefault])).toEqual([
      [work.body.data.id, true],
      [first.body.data.id, false],
    ]);
  });

  it('deleting the default promotes another', async () => {
    const a = (await request(app).post('/api/v1/me/addresses').set(await customer()).send(home)).body.data;
    const b = (await request(app).post('/api/v1/me/addresses').set(await customer()).send({ ...home, line1: 'B' })).body.data;
    await request(app).delete(`/api/v1/me/addresses/${a.id}`).set(await customer()).expect(204);
    const list = await request(app).get('/api/v1/me/addresses').set(await customer());
    expect(list.body.data).toEqual([expect.objectContaining({ id: b.id, isDefault: true })]);
  });

  it('validates pincode and phone', async () => {
    const res = await request(app)
      .post('/api/v1/me/addresses')
      .set(await customer())
      .send({ ...home, pincode: '3640', phone: '12345' });
    expect(res.status).toBe(400);
    expect(res.body.error.details.map((d: { path: string }) => d.path).sort()).toEqual(['phone', 'pincode']);
  });

  it("users never see or change each other's addresses, even in the same shop", async () => {
    const mine = (await request(app).post('/api/v1/me/addresses').set(await customer()).send(home)).body.data;
    const other = await login(SHOP_A, '+919811111111');
    const otherHeaders = as(SHOP_A, { userId: other.user.id, role: 'CUSTOMER' });
    expect((await request(app).get('/api/v1/me/addresses').set(otherHeaders)).body.data).toEqual([]);
    expect((await request(app).patch(`/api/v1/me/addresses/${mine.id}`).set(otherHeaders).send({ city: 'X' })).status).toBe(404);
    expect((await request(app).delete(`/api/v1/me/addresses/${mine.id}`).set(otherHeaders)).status).toBe(404);
  });

  it('internal checkout profile returns the user and their address for the order snapshot', async () => {
    const session = await login();
    const headers = as(SHOP_A, { userId: session.user.id, role: 'CUSTOMER' });
    const address = (await request(app).post('/api/v1/me/addresses').set(headers).send(home)).body.data;

    const res = await request(app)
      .get(`/internal/users/${session.user.id}/checkout?addressId=${address.id}`)
      .set(as(SHOP_A));
    expect(res.body.data).toMatchObject({
      user: { id: session.user.id, phone: PHONE, isBlocked: false },
      address: { id: address.id, pincode: '364001' },
    });

    // Not across shops.
    const foreign = await request(app).get(`/internal/users/${session.user.id}/checkout`).set(as(SHOP_B));
    expect(foreign.status).toBe(404);
  });
});

describe('OTP language', () => {
  it("passes the app language to the sender (WhatsApp templates per language)", async () => {
    await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: PHONE, locale: 'gu' }).expect(200);
    expect(sms.lastLocale()).toBe('gu');
    expect((await request(app).post('/api/v1/auth/otp/request').set(as(SHOP_A)).send({ phone: '+919800000003', locale: 'fr' })).status).toBe(400);
  });
});

describe('push devices', () => {
  const TOKEN = 'fcm-token-'.padEnd(40, 'a');
  const OTHER = 'fcm-token-'.padEnd(40, 'b');
  const register = (headers: Record<string, string>, token = TOKEN, locale = 'gu') =>
    request(app).put('/api/v1/me/devices').set(headers).send({ token, platform: 'android', locale });
  const targets = (shopId: string, body: Record<string, unknown>) =>
    request(app).post('/internal/devices/targets').set(as(shopId)).send(body);

  it('registers a phone; the token follows whoever logs in on it next', async () => {
    const first = await login(SHOP_A, '+919800000001');
    expect((await register(as(SHOP_A, { userId: first.user.id, role: 'CUSTOMER' }))).status).toBe(204);
    clock = new Date(clock.getTime() + 60_000);
    const second = await login(SHOP_A, '+919800000002');
    await register(as(SHOP_A, { userId: second.user.id, role: 'CUSTOMER' }), TOKEN, 'hi');

    const res = await targets(SHOP_A, { userIds: [first.user.id, second.user.id] });
    expect(res.body.data).toEqual([{ userId: second.user.id, token: TOKEN, platform: 'android', locale: 'hi' }]);
  });

  it('admins target owner and staff only; blocked users get nothing', async () => {
    const customer = await login(SHOP_A, '+919800000001');
    const owner = await login(SHOP_A, '+919800000002');
    await rawPrisma.user.update({ where: { id: owner.user.id }, data: { role: 'OWNER' } });
    await register(as(SHOP_A, { userId: customer.user.id, role: 'CUSTOMER' }), TOKEN);
    await register(as(SHOP_A, { userId: owner.user.id, role: 'OWNER' }), OTHER);

    expect((await targets(SHOP_A, { admins: true })).body.data.map((t: { token: string }) => t.token)).toEqual([OTHER]);
    expect((await targets(SHOP_A, {})).body.data).toEqual([]);
    await rawPrisma.user.update({ where: { id: owner.user.id }, data: { isBlocked: true } });
    expect((await targets(SHOP_A, { admins: true })).body.data).toEqual([]);
  });

  it("logout with the device token stops pushes to that phone; another shop sees nothing", async () => {
    const session = await login();
    await register(as(SHOP_A, { userId: session.user.id, role: 'CUSTOMER' }));
    expect((await targets(SHOP_B, { userIds: [session.user.id] })).body.data).toEqual([]);
    await request(app).post('/internal/devices/remove').set(as(SHOP_B)).send({ tokens: [TOKEN] });
    expect((await targets(SHOP_A, { userIds: [session.user.id] })).body.data).toHaveLength(1);

    await request(app)
      .post('/api/v1/auth/logout')
      .set(as(SHOP_A))
      .send({ refreshToken: session.refreshToken, deviceToken: TOKEN })
      .expect(204);
    expect((await targets(SHOP_A, { userIds: [session.user.id] })).body.data).toEqual([]);
  });

  it('validates input and needs login', async () => {
    const session = await login();
    const headers = as(SHOP_A, { userId: session.user.id, role: 'CUSTOMER' });
    expect((await request(app).put('/api/v1/me/devices').set(headers).send({ token: 'x', platform: 'android', locale: 'gu' })).status).toBe(400);
    expect((await request(app).put('/api/v1/me/devices').set(headers).send({ token: TOKEN, platform: 'web', locale: 'gu' })).status).toBe(400);
    expect((await register(as(SHOP_A))).status).toBe(401);
  });
});

describe('team (owner manages staff and riders)', () => {
  async function owner(shopId = SHOP_A) {
    const session = await login(shopId, '+919800000009');
    await rawPrisma.user.update({ where: { id: session.user.id }, data: { role: 'OWNER' } });
    return { id: session.user.id, headers: () => as(shopId, { userId: session.user.id, role: 'OWNER' }) };
  }

  it('owner adds a rider by phone, lists, removes; riders appear for delivery', async () => {
    const o = await owner();
    const added = await request(app).post('/api/v1/admin/team').set(o.headers()).send({ phone: '98111 22233', role: 'RIDER', name: 'Raju' });
    expect(added.status).toBe(201);
    expect(added.body.data).toMatchObject({ phone: '+919811122233', role: 'RIDER', name: 'Raju' });

    const list = await request(app).get('/api/v1/admin/team').set(o.headers());
    expect(list.body.data.map((m: { role: string }) => m.role)).toEqual(['OWNER', 'RIDER']);
    const riders = await request(app).get('/internal/users/riders').set(as(SHOP_A));
    expect(riders.body.data).toEqual([{ id: added.body.data.id, name: 'Raju', phone: '+919811122233' }]);
    expect((await request(app).get('/internal/users/riders').set(as(SHOP_B))).body.data).toEqual([]);

    expect((await request(app).delete(`/api/v1/admin/team/${added.body.data.id}`).set(o.headers())).status).toBe(204);
    expect((await request(app).get('/internal/users/riders').set(as(SHOP_A))).body.data).toEqual([]);
  });

  it('promoting a logged-in customer ends their sessions', async () => {
    const customer = await login(SHOP_A, '+919800000001');
    clock = new Date(clock.getTime() + 60_000);
    const o = await owner();
    await request(app).post('/api/v1/admin/team').set(o.headers()).send({ phone: '+919800000001', role: 'STAFF' }).expect(201);
    const refreshed = await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: customer.refreshToken });
    expect(refreshed.status).toBe(401);
  });

  it("only the owner manages the team; the owner's role is locked; shops are separate", async () => {
    const o = await owner();
    expect((await request(app).get('/api/v1/admin/team').set(as(SHOP_A, { userId: o.id, role: 'STAFF' }))).status).toBe(403);
    const self = await request(app).post('/api/v1/admin/team').set(o.headers()).send({ phone: '+919800000009', role: 'RIDER' });
    expect(self.body.error.code).toBe('OWNER_ROLE_LOCKED');
    expect((await request(app).delete(`/api/v1/admin/team/${o.id}`).set(o.headers())).status).toBe(404);

    const rider = (await request(app).post('/api/v1/admin/team').set(o.headers()).send({ phone: '+919811122233', role: 'RIDER' })).body.data;
    clock = new Date(clock.getTime() + 60_000);
    const other = await owner(SHOP_B);
    expect((await request(app).delete(`/api/v1/admin/team/${rider.id}`).set(other.headers())).status).toBe(404);
    expect((await request(app).get('/api/v1/admin/team').set(other.headers())).body.data).toHaveLength(1);
  });
});

describe('deleting my account', () => {
  const home = { line1: '12 Station Road', city: 'Bhavnagar', pincode: '364001' };
  const TOKEN = 'fcm-token-'.padEnd(40, 'd');

  it('removes phone, name, addresses, devices and sessions; the phone starts fresh next time', async () => {
    const session = await login();
    const me = () => as(SHOP_A, { userId: session.user.id, role: 'CUSTOMER' });
    await request(app).patch('/api/v1/me').set(me()).send({ name: 'Asha' }).expect(200);
    await request(app).post('/api/v1/me/addresses').set(me()).send(home).expect(201);
    await request(app).put('/api/v1/me/devices').set(me()).send({ token: TOKEN, platform: 'android', locale: 'gu' }).expect(204);

    const res = await request(app).delete('/api/v1/me').set(me());
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ deleted: true });

    const row = await rawPrisma.user.findUniqueOrThrow({ where: { id: session.user.id } });
    expect(row).toMatchObject({ phone: `deleted:${session.user.id}`, name: null, isBlocked: true });
    expect(row.deletedAt).not.toBeNull();
    expect(await rawPrisma.address.count({ where: { userId: session.user.id } })).toBe(0);
    expect(await rawPrisma.device.count({ where: { userId: session.user.id } })).toBe(0);
    expect(await rawPrisma.refreshToken.count({ where: { userId: session.user.id } })).toBe(0);

    expect((await request(app).get('/api/v1/me').set(me())).status).toBe(404);
    expect((await request(app).get(`/internal/users/${session.user.id}/checkout`).set(as(SHOP_A))).status).toBe(404);
    expect((await request(app).post('/api/v1/auth/refresh').set(as(SHOP_A)).send({ refreshToken: session.refreshToken })).status).toBe(401);

    clock = new Date(clock.getTime() + 60_000);
    const again = await login();
    expect(again.isNewUser).toBe(true);
    expect(again.user.id).not.toBe(session.user.id);
  });

  it('waits for orders in progress', async () => {
    const session = await login();
    openOrders.set(session.user.id, 1);
    const res = await request(app).delete('/api/v1/me').set(as(SHOP_A, { userId: session.user.id, role: 'CUSTOMER' }));
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ACCOUNT_HAS_OPEN_ORDERS');
    expect((await rawPrisma.user.findUniqueOrThrow({ where: { id: session.user.id } })).deletedAt).toBeNull();
  });

  it('owner and team accounts cannot delete themselves', async () => {
    const session = await login();
    for (const [role, code] of [
      ['OWNER', 'ACCOUNT_DELETE_OWNER'],
      ['RIDER', 'ACCOUNT_DELETE_TEAM'],
    ] as const) {
      await rawPrisma.user.update({ where: { id: session.user.id }, data: { role } });
      const res = await request(app).delete('/api/v1/me').set(as(SHOP_A, { userId: session.user.id, role }));
      expect(res.body.error.code).toBe(code);
    }
  });

  it("cannot delete another shop's user", async () => {
    const session = await login();
    const res = await request(app).delete('/api/v1/me').set(as(SHOP_B, { userId: session.user.id, role: 'CUSTOMER' }));
    expect(res.status).toBe(404);
    expect((await rawPrisma.user.findUniqueOrThrow({ where: { id: session.user.id } })).deletedAt).toBeNull();
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    const srcDir = fileURLToPath(new URL('../src/', import.meta.url));
    const offenders: string[] = [];
    const walk = (dir: string) => {
      for (const name of readdirSync(dir)) {
        const path = join(dir, name);
        if (name === 'generated') continue;
        if (statSync(path).isDirectory()) walk(path);
        else if (name.endsWith('.ts') && /\brawPrisma\b/.test(readFileSync(path, 'utf8'))) {
          offenders.push(relative(srcDir, path));
        }
      }
    };
    walk(srcDir);
    expect(offenders.filter((f) => f !== 'db.ts' && f !== 'main.ts')).toEqual([]);
  });
});
