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
  sent: OtpMessage[] = [];
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
  app = await build();
  await rawPrisma.refreshToken.deleteMany();
  await rawPrisma.otpChallenge.deleteMany();
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
    expect(res.body.data).toEqual({ expiresInSeconds: 300, resendAfterSeconds: 30 });
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
