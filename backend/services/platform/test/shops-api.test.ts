import { createHash } from 'node:crypto';
import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { FakeDirectory, buildApp, cleanDb, db } from './helpers.js';

const TOKEN = 'test-platform-token-test-platform-token-0123';
const hash = createHash('sha256').update(TOKEN).digest('hex');
let t: ReturnType<typeof buildApp>;

const body = (slug = 'new_kirana') => ({
  clientJson: { slug, shop: { name: 'New Kirana' } },
  ownerPhone: '+919825012345',
  ownerName: 'Mahesh',
  feePaise: 99_900,
  dueDay: 10,
});
const call = (payload: unknown, token = TOKEN) => request(t.app).post('/api/shops').set('authorization', `Bearer ${token}`).send(payload as object);

beforeEach(async () => {
  await cleanDb();
  t = buildApp({ apiTokenHash: hash, directory: new FakeDirectory() });
});
afterAll(async () => {
  await cleanDb();
  await db.$disconnect();
});

describe('POST /api/shops (new-shop command)', () => {
  it('needs the token', async () => {
    expect((await call(body(), 'wrong')).status).toBe(401);
    expect((await request(t.app).post('/api/shops').send(body())).status).toBe(401);
    const off = buildApp({ directory: new FakeDirectory() });
    expect((await request(off.app).post('/api/shops').set('authorization', `Bearer ${TOKEN}`).send(body())).status).toBe(404);
  });

  it('creates the shop, its owner and the subscription; a re-run keeps the subscription', async () => {
    const res = await call(body());
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ slug: 'new_kirana', created: true, subscription: 'created', nextDueDate: '2026-12-10' });
    expect(t.directory.synced).toEqual([body().clientJson]);
    expect(t.directory.owners).toEqual([{ shopId: res.body.data.shopId, phone: '+919825012345', name: 'Mahesh' }]);

    const again = await call({ ...body(), feePaise: 1_000, dueDay: 2 });
    expect(again.body.data).toMatchObject({ shopId: res.body.data.shopId, created: false, subscription: 'kept', nextDueDate: '2026-12-10' });
    expect((await db.subscription.findUniqueOrThrow({ where: { shopId: res.body.data.shopId } })).feePaise).toBe(99_900);
  });

  it('validates the request', async () => {
    const res = await call({ ...body(), dueDay: 31, feePaise: -5 });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(t.directory.synced).toEqual([]);
  });
});
