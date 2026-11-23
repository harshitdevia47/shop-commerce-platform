import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import pino from 'pino';
import {
  INTERNAL_HEADERS,
  errorHandler,
  getContext,
  internalAuth,
  requireAdmin,
  signInternalHeaders,
  verifyInternalHeaders,
} from '../src/index.js';

const SECRET = 'test-secret-test-secret-test-secret-123';
const identity = { requestId: 'req-1', shopId: 'shop-a', userId: 'user-1', role: 'OWNER' as const, clientIp: '1.2.3.4' };

describe('internal header signing', () => {
  it('round-trips a signed identity', () => {
    const headers = signInternalHeaders(identity, SECRET);
    expect(verifyInternalHeaders(headers, SECRET)).toEqual(identity);
  });

  it('rejects a tampered shop id', () => {
    const headers = { ...signInternalHeaders(identity, SECRET), [INTERNAL_HEADERS.shopId]: 'shop-b' };
    expect(() => verifyInternalHeaders(headers, SECRET)).toThrow(/signature/);
  });

  it('rejects an added shop id when none was signed', () => {
    const headers = {
      ...signInternalHeaders({ requestId: 'r' }, SECRET),
      [INTERNAL_HEADERS.shopId]: 'shop-b',
    };
    expect(() => verifyInternalHeaders(headers, SECRET)).toThrow(/signature/);
  });

  it('rejects a tampered client IP', () => {
    const headers = { ...signInternalHeaders(identity, SECRET), [INTERNAL_HEADERS.clientIp]: '9.9.9.9' };
    expect(() => verifyInternalHeaders(headers, SECRET)).toThrow(/signature/);
  });

  it('rejects the wrong secret', () => {
    const headers = signInternalHeaders(identity, SECRET);
    expect(() => verifyInternalHeaders(headers, `${SECRET}x`)).toThrow(/signature/);
  });

  it('rejects stale timestamps', () => {
    const now = Date.now();
    const headers = signInternalHeaders(identity, SECRET, now - 120_000);
    expect(() => verifyInternalHeaders(headers, SECRET, now)).toThrow(/expired/);
  });

  it('rejects missing headers', () => {
    expect(() => verifyInternalHeaders({}, SECRET)).toThrow(/Missing/);
  });

  it('rejects unknown roles', () => {
    const headers = { ...signInternalHeaders(identity, SECRET), [INTERNAL_HEADERS.role]: 'ROOT' };
    expect(() => verifyInternalHeaders(headers, SECRET)).toThrow(/role/);
  });
});

describe('internalAuth middleware', () => {
  const logger = pino({ level: 'silent' });
  const app = express();
  app.use(internalAuth(SECRET));
  app.get('/whoami', (_req, res) => {
    res.json(getContext());
  });
  app.get('/admin', requireAdmin, (_req, res) => {
    res.json({ ok: true });
  });
  app.use(errorHandler(logger));

  it('exposes verified identity via context', async () => {
    const res = await request(app).get('/whoami').set(signInternalHeaders(identity, SECRET));
    expect(res.status).toBe(200);
    expect(res.body).toEqual(identity);
  });

  it('returns 401 without signature', async () => {
    const res = await request(app).get('/whoami');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INTERNAL_AUTH_MISSING');
  });

  it('enforces admin role', async () => {
    const customer = signInternalHeaders({ ...identity, role: 'CUSTOMER' }, SECRET);
    expect((await request(app).get('/admin').set(customer)).status).toBe(403);
    const anonymous = signInternalHeaders({ requestId: 'r', shopId: 'shop-a' }, SECRET);
    expect((await request(app).get('/admin').set(anonymous)).status).toBe(401);
    const owner = signInternalHeaders(identity, SECRET);
    expect((await request(app).get('/admin').set(owner)).status).toBe(200);
  });
});
