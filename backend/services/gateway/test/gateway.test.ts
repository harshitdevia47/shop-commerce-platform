import type { AddressInfo } from 'node:net';
import type { Server } from 'node:http';
import { createLogger, verifyInternalHeaders } from '@qc/common';
import express from 'express';
import { SignJWT, exportSPKI, generateKeyPair } from 'jose';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { createGatewayApp } from '../src/app.js';
import { createAccessTokenVerifier } from '../src/auth.js';
import { MemoryRateLimitStore } from '@qc/common';
import { buildRoutes } from '../src/routes.js';
import { ShopResolver, type ShopRef } from '../src/shop-resolver.js';

const SECRET = 'gateway-test-secret-gateway-test-secret';
const ISSUER = 'qc-identity';
const SHOPS: Record<string, ShopRef> = {
  shop_a: { id: 'id-a', slug: 'shop_a', isActive: true },
  shop_b: { id: 'id-b', slug: 'shop_b', isActive: true },
  closed: { id: 'id-c', slug: 'closed', isActive: false },
};

let upstream: Server;
let upstreamUrl: string;
let privateKey: Awaited<ReturnType<typeof generateKeyPair>>["privateKey"];
let app: express.Express;
let lookups = 0;

async function token(claims: Record<string, unknown>, expiresIn = '15m'): Promise<string> {
  return new SignJWT({ typ: 'access', ...claims })
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuer(ISSUER)
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(privateKey);
}

function buildApp(perMinute = 1000, target = upstreamUrl) {
  return createGatewayApp({
    logger: createLogger('gateway-test', 'silent'),
    routes: buildRoutes({ tenant: target, identity: target, catalog: target, media: target, order: target, payment: target, delivery: target, reporting: target }),
    mediaStaticTarget: target,
    shops: new ShopResolver(async (slug) => {
      lookups++;
      return SHOPS[slug] ?? null;
    }, 60_000),
    verifyAccessToken: verifier,
    rateLimit: { store: new MemoryRateLimitStore(), perMinute },
    internalSecret: SECRET,
  });
}

let verifier: Awaited<ReturnType<typeof createAccessTokenVerifier>>;

beforeAll(async () => {
  const keys = await generateKeyPair('RS256');
  privateKey = keys.privateKey;
  verifier = await createAccessTokenVerifier(await exportSPKI(keys.publicKey), ISSUER);

  // Fake upstream: verifies the gateway signature and echoes what it received.
  const echo = express();
  echo.use(express.json());
  echo.all('/{*path}', (req, res) => {
    try {
      const identity = verifyInternalHeaders(req.headers, SECRET);
      res.json({ identity, path: req.originalUrl, body: req.body, authorization: req.headers.authorization ?? null });
    } catch (err) {
      res.status(401).json({ error: { code: 'BAD_SIGNATURE', message: String(err) } });
    }
  });
  await new Promise<void>((resolve) => {
    upstream = echo.listen(0, () => resolve());
  });
  upstreamUrl = `http://127.0.0.1:${(upstream.address() as AddressInfo).port}`;
});

beforeEach(() => {
  app = buildApp();
  lookups = 0;
});

afterAll(() => {
  upstream.close();
});

describe('gateway', () => {
  it('serves /health without a shop key', async () => {
    expect((await request(app).get('/health')).status).toBe(200);
  });

  it('requires X-Shop-Key', async () => {
    const res = await request(app).get('/api/v1/shop/config');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('SHOP_KEY_REQUIRED');
  });

  it('404s unknown and malformed shop keys', async () => {
    expect((await request(app).get('/api/v1/shop/config').set('x-shop-key', 'nope')).status).toBe(404);
    expect((await request(app).get('/api/v1/shop/config').set('x-shop-key', '../etc')).status).toBe(404);
  });

  it('403s inactive shops', async () => {
    const res = await request(app).get('/api/v1/shop/config').set('x-shop-key', 'closed');
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('SHOP_INACTIVE');
  });

  it('proxies with a signed identity for the resolved shop', async () => {
    const res = await request(app).get('/api/v1/shop/config?x=1').set('x-shop-key', 'shop_a');
    expect(res.status).toBe(200);
    expect(res.body.identity.shopId).toBe('id-a');
    expect(res.body.identity.userId).toBeUndefined();
    expect(res.body.path).toBe('/api/v1/shop/config?x=1');
    expect(res.headers['x-request-id']).toBe(res.body.identity.requestId);
  });

  it('forwards the client IP inside the signed identity', async () => {
    const res = await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a').set('x-internal-client-ip', '6.6.6.6');
    expect(res.body.identity.clientIp).toBeDefined();
    expect(res.body.identity.clientIp).not.toBe('6.6.6.6');
  });

  it('requires login for /api/v1/me', async () => {
    expect((await request(app).get('/api/v1/me').set('x-shop-key', 'shop_a')).status).toBe(401);
  });

  it('streams request bodies through', async () => {
    const res = await request(app).post('/api/v1/shop/anything').set('x-shop-key', 'shop_a').send({ hello: 'world' });
    expect(res.body.body).toEqual({ hello: 'world' });
  });

  it('strips client-supplied internal headers', async () => {
    const res = await request(app)
      .get('/api/v1/shop/config')
      .set('x-shop-key', 'shop_a')
      .set('x-internal-shop-id', 'id-b')
      .set('x-internal-role', 'OWNER')
      .set('x-internal-user-id', 'attacker');
    expect(res.body.identity).toMatchObject({ shopId: 'id-a' });
    expect(res.body.identity.role).toBeUndefined();
    expect(res.body.identity.userId).toBeUndefined();
  });

  it('dev media passthrough serves /media without shop key or identity headers', async () => {
    const res = await request(app).get('/media/shop-id/2026/11/x-thumb.webp');
    expect(res.status).toBe(401); // the echo upstream saw no gateway signature
    expect(res.body.error.code).toBe('BAD_SIGNATURE');
    const post = await request(app).post('/media/x');
    expect(post.body.error.code).toBe('ROUTE_NOT_FOUND');
  });

  it('catalog browsing is public; catalog admin and uploads need an admin', async () => {
    const browse = await request(app).get('/api/v1/catalog/products').set('x-shop-key', 'shop_a');
    expect(browse.status).toBe(200);
    expect(browse.body.identity.shopId).toBe('id-a');
    for (const path of ['/api/v1/admin/catalog/products', '/api/v1/admin/media']) {
      expect((await request(app).post(path).set('x-shop-key', 'shop_a')).status).toBe(401);
      const customer = await token({ sub: 'u1', shopId: 'id-a', role: 'CUSTOMER' });
      expect((await request(app).post(path).set('x-shop-key', 'shop_a').set('authorization', `Bearer ${customer}`)).status).toBe(403);
      const staff = await token({ sub: 'u2', shopId: 'id-a', role: 'STAFF' });
      expect((await request(app).post(path).set('x-shop-key', 'shop_a').set('authorization', `Bearer ${staff}`)).status).toBe(200);
    }
  });

  it('order quote is public; placing orders and payments need login; shop order admin needs a shop role', async () => {
    const shop = { 'x-shop-key': 'shop_a' };
    expect((await request(app).post('/api/v1/orders/quote').set(shop)).status).toBe(200);
    expect((await request(app).post('/api/v1/orders').set(shop)).status).toBe(401);
    expect((await request(app).get('/api/v1/payments/orders/x').set(shop)).status).toBe(401);
    const customer = await token({ sub: 'u1', shopId: 'id-a', role: 'CUSTOMER' });
    const auth = { ...shop, authorization: `Bearer ${customer}` };
    expect((await request(app).post('/api/v1/orders').set(auth)).status).toBe(200);
    expect((await request(app).get('/api/v1/admin/orders').set(auth)).status).toBe(403);
    expect((await request(app).post('/api/v1/admin/payments/orders/x/mark-paid').set(auth)).status).toBe(403);
  });

  it('delivery routes: riders only on /rider, team only for the owner', async () => {
    const shop = { 'x-shop-key': 'shop_a' };
    const as = async (role: string) => ({ ...shop, authorization: `Bearer ${await token({ sub: 'u1', shopId: 'id-a', role })}` });
    expect((await request(app).get('/api/v1/rider/deliveries').set(await as('RIDER'))).status).toBe(200);
    expect((await request(app).get('/api/v1/rider/deliveries').set(await as('OWNER'))).status).toBe(403);
    expect((await request(app).get('/api/v1/admin/riders').set(await as('STAFF'))).status).toBe(200);
    expect((await request(app).get('/api/v1/admin/riders').set(await as('RIDER'))).status).toBe(403);
    expect((await request(app).get('/api/v1/admin/team').set(await as('OWNER'))).status).toBe(200);
    expect((await request(app).get('/api/v1/admin/team').set(await as('STAFF'))).status).toBe(403);
    expect((await request(app).get('/api/v1/admin/reports/summary').set(await as('OWNER'))).status).toBe(200);
    expect((await request(app).get('/api/v1/admin/reports/summary').set(await as('STAFF'))).status).toBe(403);
    expect((await request(app).get('/api/v1/deliveries/orders/x').set(await as('CUSTOMER'))).status).toBe(200);
    expect((await request(app).get('/api/v1/deliveries/orders/x').set(shop)).status).toBe(401);
  });

  it('slots are public; private photos need login; returns admin needs a shop role', async () => {
    const shop = { 'x-shop-key': 'shop_a' };
    expect((await request(app).get('/api/v1/orders/slots').set(shop)).status).toBe(200);
    expect((await request(app).get('/api/v1/media/private/x').set(shop)).status).toBe(401);
    const customer = { ...shop, authorization: `Bearer ${await token({ sub: 'u1', shopId: 'id-a', role: 'CUSTOMER' })}` };
    expect((await request(app).get('/api/v1/media/private/x').set(customer)).status).toBe(200);
    expect((await request(app).get('/api/v1/admin/returns').set(customer)).status).toBe(403);
  });

  it('never routes /internal paths', async () => {
    const res = await request(app).get('/internal/shops/by-slug/shop_a').set('x-shop-key', 'shop_a');
    expect(res.status).toBe(404);
  });

  it('404s unknown routes', async () => {
    expect((await request(app).get('/api/v1/nothing').set('x-shop-key', 'shop_a')).status).toBe(404);
  });

  it('caches shop lookups', async () => {
    await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a');
    await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a');
    expect(lookups).toBe(1);
  });
});

describe('gateway auth', () => {
  it('forwards user identity from a valid token and drops the Authorization header', async () => {
    const jwt = await token({ sub: 'user-1', shopId: 'id-a', role: 'CUSTOMER' });
    const res = await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a').set('authorization', `Bearer ${jwt}`);
    expect(res.body.identity).toMatchObject({ shopId: 'id-a', userId: 'user-1', role: 'CUSTOMER' });
    expect(res.body.authorization).toBeNull();
  });

  it('rejects a token from another shop', async () => {
    const jwt = await token({ sub: 'user-1', shopId: 'id-b', role: 'OWNER' });
    const res = await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a').set('authorization', `Bearer ${jwt}`);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('TOKEN_SHOP_MISMATCH');
  });

  it('rejects expired, forged and malformed tokens', async () => {
    const expired = await token({ sub: 'u', shopId: 'id-a', role: 'OWNER' }, '-1m');
    const r1 = await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a').set('authorization', `Bearer ${expired}`);
    expect(r1.body.error.code).toBe('TOKEN_EXPIRED');

    const other = await generateKeyPair('RS256');
    const forged = await new SignJWT({ typ: 'access', sub: 'u', shopId: 'id-a', role: 'OWNER' })
      .setProtectedHeader({ alg: 'RS256' })
      .setIssuer(ISSUER)
      .setExpirationTime('5m')
      .sign(other.privateKey);
    const r2 = await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a').set('authorization', `Bearer ${forged}`);
    expect(r2.body.error.code).toBe('TOKEN_INVALID');

    const r3 = await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a').set('authorization', 'Basic abc');
    expect(r3.status).toBe(401);
  });

  it('rejects refresh-type tokens used as access tokens', async () => {
    const jwt = await token({ sub: 'u', shopId: 'id-a', role: 'OWNER', typ: 'refresh' });
    const res = await request(app).get('/api/v1/shop/config').set('x-shop-key', 'shop_a').set('authorization', `Bearer ${jwt}`);
    expect(res.body.error.code).toBe('TOKEN_INVALID');
  });

  it('enforces route auth and roles', async () => {
    const path = '/api/v1/admin/settings/delivery';
    expect((await request(app).get(path).set('x-shop-key', 'shop_a')).status).toBe(401);

    const customer = await token({ sub: 'u', shopId: 'id-a', role: 'CUSTOMER' });
    expect((await request(app).get(path).set('x-shop-key', 'shop_a').set('authorization', `Bearer ${customer}`)).status).toBe(403);

    const owner = await token({ sub: 'u', shopId: 'id-a', role: 'OWNER' });
    const ok = await request(app).get(path).set('x-shop-key', 'shop_a').set('authorization', `Bearer ${owner}`);
    expect(ok.status).toBe(200);
    expect(ok.body.identity.role).toBe('OWNER');
  });
});

describe('gateway resilience', () => {
  it('rate limits per shop and IP', async () => {
    const limited = buildApp(2);
    for (let i = 0; i < 2; i++) {
      expect((await request(limited).get('/api/v1/shop/config').set('x-shop-key', 'shop_a')).status).toBe(200);
    }
    const res = await request(limited).get('/api/v1/shop/config').set('x-shop-key', 'shop_a');
    expect(res.status).toBe(429);
    // other shop has its own bucket
    expect((await request(limited).get('/api/v1/shop/config').set('x-shop-key', 'shop_b')).status).toBe(200);
  });

  it('returns 502 when the upstream is down', async () => {
    const broken = buildApp(1000, 'http://127.0.0.1:1');
    const res = await request(broken).get('/api/v1/shop/config').set('x-shop-key', 'shop_a');
    expect(res.status).toBe(502);
    expect(res.body.error.code).toBe('UPSTREAM_UNAVAILABLE');
  });
});
