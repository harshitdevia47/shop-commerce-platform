import type { Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import express from 'express';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AppError, createInternalClient, internalAuth, runWithContext } from '../src/index.js';

const SECRET = 'client-test-secret-client-test-secret';
let server: Server;
let baseUrl: string;

beforeAll(async () => {
  const app = express();
  app.use(express.json());
  app.use(internalAuth(SECRET));
  app.post('/ok', (req, res) => {
    res.json({ data: { echo: req.body, shop: req.headers['x-internal-shop-id'] } });
  });
  app.post('/conflict', (_req, res) => {
    res.status(409).json({ error: { code: 'OUT_OF_STOCK', message: 'short', details: { items: [1] } } });
  });
  app.post('/boom', (_req, res) => {
    res.status(500).json({ error: { code: 'INTERNAL', message: 'secret stack', details: { sql: 'x' } } });
  });
  app.use(((err: AppError, _req, res, _next) => {
    res.status(err.status ?? 500).json({ error: { code: err.code } });
  }) as express.ErrorRequestHandler);
  await new Promise<void>((resolve) => {
    server = app.listen(0, () => resolve());
  });
  baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
afterAll(() => server.close());

describe('createInternalClient', () => {
  const client = () => createInternalClient({ baseUrl, secret: SECRET, caller: 'test' });

  it('signs with the current context and unwraps data', async () => {
    const data = await runWithContext({ requestId: 'r1', shopId: 'shop-1' }, () =>
      client().post<{ echo: unknown; shop: string }>('/ok', { body: { a: 1 } }),
    );
    expect(data).toEqual({ echo: { a: 1 }, shop: 'shop-1' });
  });

  it('keeps code, status and details of 4xx errors', async () => {
    const error = await client().post('/conflict').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(AppError);
    expect(error).toMatchObject({ code: 'OUT_OF_STOCK', status: 409, details: { items: [1] } });
  });

  it('hides details of upstream 5xx and reports 502', async () => {
    const error = await client().post('/boom').catch((e: unknown) => e);
    expect(error).toMatchObject({ status: 502, details: undefined });
  });

  it('reports an unreachable upstream as 503', async () => {
    const down = createInternalClient({ baseUrl: 'http://127.0.0.1:1', secret: SECRET, caller: 'test', timeoutMs: 500 });
    await expect(down.get('/x')).rejects.toMatchObject({ code: 'UPSTREAM_UNAVAILABLE', status: 503 });
  });
});
