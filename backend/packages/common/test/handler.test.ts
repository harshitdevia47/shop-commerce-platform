import express from 'express';
import pino from 'pino';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { Errors, errorHandler, handler, notFoundHandler } from '../src/index.js';

const app = express();
app.use(express.json());
app.post(
  '/items/:id',
  handler(
    {
      params: z.object({ id: z.string().uuid() }),
      body: z.object({ qty: z.number().int().positive() }),
    },
    ({ params, body }) => ({ id: params.id, qty: body.qty }),
    201,
  ),
);
app.get(
  '/fail',
  handler({}, () => {
    throw Errors.conflict('ORDER_NOT_CANCELLABLE', 'Too late');
  }),
);
app.get(
  '/crash',
  handler({}, async () => {
    throw new Error('boom');
  }),
);
app.use(notFoundHandler);
app.use(errorHandler(pino({ level: 'silent' })));

const ID = '0195f0a0-0000-7000-8000-000000000001';

describe('handler', () => {
  it('validates input and wraps output in data', async () => {
    const res = await request(app).post(`/items/${ID}`).send({ qty: 2 });
    expect(res.status).toBe(201);
    expect(res.body).toEqual({ data: { id: ID, qty: 2 } });
  });

  it('returns VALIDATION_FAILED with details', async () => {
    const res = await request(app).post('/items/not-a-uuid').send({ qty: 0 });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(res.body.error.details[0].location).toBe('params');
  });

  it('returns INVALID_JSON for malformed bodies', async () => {
    const res = await request(app).post(`/items/${ID}`).set('content-type', 'application/json').send('{bad');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_JSON');
  });

  it('maps AppError to its status and code', async () => {
    const res = await request(app).get('/fail');
    expect(res.status).toBe(409);
    expect(res.body).toEqual({ error: { code: 'ORDER_NOT_CANCELLABLE', message: 'Too late' } });
  });

  it('hides unexpected errors', async () => {
    const res = await request(app).get('/crash');
    expect(res.status).toBe(500);
    expect(res.body.error).toEqual({ code: 'INTERNAL', message: 'Something went wrong' });
  });

  it('returns ROUTE_NOT_FOUND for unknown routes', async () => {
    const res = await request(app).get('/nope');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('ROUTE_NOT_FOUND');
  });
});
