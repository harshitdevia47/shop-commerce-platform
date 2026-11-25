import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import { TenantContextError, createLogger, requireShopId, runWithContext, signInternalHeaders } from '@qc/common';
import { parseClientConfig, type ClientConfig } from '@qc/config-schema';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { createTenantApp } from '../src/app.js';
import { createDb } from '../src/db.js';
import { createShopsService, type ShopRef } from '../src/modules/shops/shops.service.js';

const secret = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const app = createTenantApp({ db, logger: createLogger('tenant-test', 'silent'), internalSecret: secret });
const shops = createShopsService(db);

const clientsDir = fileURLToPath(new URL('../../../../clients/', import.meta.url));
const loadClient = (slug: string): ClientConfig =>
  parseClientConfig(JSON.parse(readFileSync(join(clientsDir, slug, 'client.json'), 'utf8')));

let shopA: ShopRef;
let shopB: ShopRef;

const as = (shopId?: string) => signInternalHeaders({ requestId: randomUUID(), shopId }, secret);
const inShop = <T>(shopId: string, fn: () => Promise<T>) => runWithContext({ requestId: 'test', shopId }, fn);

beforeAll(async () => {
  shopA = await shops.upsertFromClientConfig(loadClient('sharma_kirana'));
  shopB = await shops.upsertFromClientConfig(loadClient('style_hub'));
});

beforeEach(async () => {
  await rawPrisma.deliverySlot.deleteMany();
});

afterAll(async () => {
  await rawPrisma.$disconnect();
});

describe('owner settings', () => {
  const owner = (shopId: string) => signInternalHeaders({ requestId: randomUUID(), shopId, userId: randomUUID(), role: 'OWNER' }, secret);
  const staff = (shopId: string) => signInternalHeaders({ requestId: randomUUID(), shopId, userId: randomUUID(), role: 'STAFF' }, secret);
  const patch = (body: object, headers = owner(shopA.id)) => request(app).patch('/api/v1/admin/settings').set(headers).send(body);
  const config = async (shopId = shopA.id) => (await request(app).get('/api/v1/shop/config').set(as(shopId))).body.data;

  beforeEach(async () => {
    await shops.upsertFromClientConfig(loadClient('sharma_kirana'), { resetSettings: true });
    await shops.upsertFromClientConfig(loadClient('style_hub'), { resetSettings: true });
  });

  it('owner changes delivery, payments, features and pauses orders; customers see it', async () => {
    const res = await patch({
      delivery: { feePaise: 1500, minOrderPaise: 20_000, freeAbovePaise: null, pincodes: ['364001'] },
      payments: { upi: { enabled: true, vpa: 'newshop@okicici', payeeName: 'Sharma Kirana' } },
      features: { returns: true },
      returns: { windowDays: 3 },
      ordering: { paused: true, pausedMessage: 'Closed today for Diwali' },
      contact: { whatsapp: null },
    });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    const data = await config();
    expect(data.delivery).toMatchObject({ feePaise: 1500, minOrderPaise: 20_000, freeAbovePaise: null, pincodes: ['364001'] });
    expect(data.payments.upi.vpa).toBe('newshop@okicici');
    expect(data.features.returns).toBe(true);
    expect(data.returns).toEqual({ windowDays: 3, allowExchange: true });
    expect(data.ordering).toEqual({ paused: true, pausedMessage: 'Closed today for Diwali' });
    expect(data.shop.contact.whatsapp).toBeUndefined();
    expect(data.shop.name).toBe('Sharma Kirana'); // not editable here

    await patch({ ordering: { paused: false, pausedMessage: null } });
    expect((await config()).ordering).toEqual({ paused: false });
  });

  it('refuses invalid combinations with readable reasons', async () => {
    const noWay = await patch({ delivery: { enabled: false }, features: { storePickup: false } });
    expect(noWay.body.error.code).toBe('SETTINGS_INVALID');
    expect(JSON.stringify(noWay.body.error.details.issues)).toContain('delivery.enabled');
    expect((await patch({ payments: { cod: false, upi: { enabled: false } } })).body.error.code).toBe('SETTINGS_INVALID');
    expect((await patch({ payments: { upi: { enabled: true, vpa: 'not-an-upi-id', payeeName: 'X' } } })).body.error.code).toBe('SETTINGS_INVALID');
    expect((await patch({ delivery: { feePaise: 12.5 } })).body.error.code).toBe('SETTINGS_INVALID');
    expect((await patch({ shop: { name: 'Hacked' } })).status).toBe(400); // name is not owner-editable
    expect((await patch({ payments: { razorpay: { enabled: true } } })).status).toBe(400); // needs platform keys
  });

  it('only the owner changes settings; staff can read; each shop its own', async () => {
    expect((await patch({ delivery: { feePaise: 0 } }, staff(shopA.id))).status).toBe(403);
    expect((await request(app).get('/api/v1/admin/settings').set(staff(shopA.id))).body.data.slug).toBe('sharma_kirana');
    await patch({ delivery: { feePaise: 999 } }, owner(shopB.id));
    expect((await config(shopA.id)).delivery.feePaise).not.toBe(999);
    expect((await config(shopB.id)).delivery.feePaise).toBe(999);
  });

  it('client.json sync keeps what the owner edited, unless reset', async () => {
    await patch({ delivery: { feePaise: 4200 } });
    const synced = await shops.upsertFromClientConfig(loadClient('sharma_kirana'));
    expect(synced.keptOwnerSettings).toBe(true);
    expect((await config()).delivery.feePaise).toBe(4200);
    await shops.upsertFromClientConfig(loadClient('sharma_kirana'), { resetSettings: true });
    expect((await config()).delivery.feePaise).toBe(2000);
  });
});

describe('health', () => {
  it('serves /health and /ready without internal auth', async () => {
    expect((await request(app).get('/health')).status).toBe(200);
    expect((await request(app).get('/ready')).body.status).toBe('ready');
  });
});

describe('GET /api/v1/shop/config', () => {
  it('returns the runtime config of the shop in context', async () => {
    const res = await request(app).get('/api/v1/shop/config').set(as(shopA.id));
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id: shopA.id,
      slug: 'sharma_kirana',
      shop: { name: 'Sharma Kirana', businessType: 'grocery' },
      features: { deliverySlots: true },
      catalog: { variantStyle: 'units' },
    });
    expect(res.body.data).not.toHaveProperty('build');
    expect(res.body.data).not.toHaveProperty('branding');
  });

  it('returns each shop its own config', async () => {
    const res = await request(app).get('/api/v1/shop/config').set(as(shopB.id));
    expect(res.body.data.slug).toBe('style_hub');
  });

  it('is also served internally at /internal/shop/config', async () => {
    const res = await request(app).get('/internal/shop/config').set(as(shopB.id));
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({ id: shopB.id, catalog: { variantStyle: 'options' } });
  });

  it('rejects unsigned requests', async () => {
    const res = await request(app).get('/api/v1/shop/config').set('x-internal-shop-id', shopA.id);
    expect(res.status).toBe(401);
  });

  it('requires shop context', async () => {
    const res = await request(app).get('/api/v1/shop/config').set(as());
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('SHOP_REQUIRED');
  });

  it('returns 404 for an unknown shop id', async () => {
    const res = await request(app).get('/api/v1/shop/config').set(as(randomUUID()));
    expect(res.status).toBe(404);
  });
});

describe('GET /internal/shops/by-slug/:slug', () => {
  it('resolves a slug', async () => {
    const res = await request(app).get('/internal/shops/by-slug/sharma_kirana').set(as());
    expect(res.body.data).toEqual({ id: shopA.id, slug: 'sharma_kirana', isActive: true });
  });

  it('404s unknown slugs and 400s malformed ones', async () => {
    expect((await request(app).get('/internal/shops/by-slug/nope').set(as())).status).toBe(404);
    expect((await request(app).get('/internal/shops/by-slug/Bad-Slug').set(as())).status).toBe(400);
  });
});

describe('tenant isolation (scoped db client)', () => {
  const slot = { dayOfWeek: 1, startMinute: 540, endMinute: 660, capacity: 10 };

  async function seed() {
    const a = await inShop(shopA.id, () => db.deliverySlot.create({ data: { ...slot, shopId: requireShopId() } }));
    const b = await inShop(shopB.id, () => db.deliverySlot.create({ data: { ...slot, shopId: requireShopId() } }));
    return { a, b };
  }

  it('creates rows in the context shop', async () => {
    const { a, b } = await seed();
    expect(a.shopId).toBe(shopA.id);
    expect(b.shopId).toBe(shopB.id);
  });

  it('lists only own rows', async () => {
    const { a } = await seed();
    const rows = await inShop(shopA.id, () => db.deliverySlot.findMany());
    expect(rows.map((r) => r.id)).toEqual([a.id]);
  });

  it('cannot read another shop row by id', async () => {
    const { b } = await seed();
    expect(await inShop(shopA.id, () => db.deliverySlot.findUnique({ where: { id: b.id } }))).toBeNull();
  });

  it('cannot update or delete another shop row by id', async () => {
    const { b } = await seed();
    await expect(
      inShop(shopA.id, () => db.deliverySlot.update({ where: { id: b.id }, data: { capacity: 99 } })),
    ).rejects.toThrow();
    const result = await inShop(shopA.id, () => db.deliverySlot.deleteMany({ where: { id: b.id } }));
    expect(result.count).toBe(0);
    const untouched = await rawPrisma.deliverySlot.findUniqueOrThrow({ where: { id: b.id } });
    expect(untouched.capacity).toBe(10);
  });

  it('refuses to create rows for another shop', async () => {
    await expect(
      inShop(shopA.id, () => db.deliverySlot.create({ data: { ...slot, shopId: shopB.id } })),
    ).rejects.toThrow(TenantContextError);
  });

  it('refuses tenant queries without context', async () => {
    await expect(db.deliverySlot.findMany()).rejects.toThrow(TenantContextError);
  });

  it('scopes queries inside interactive transactions', async () => {
    await seed();
    const count = await inShop(shopA.id, () => db.$transaction((tx) => tx.deliverySlot.count()));
    expect(count).toBe(1);
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts within src/', () => {
    const srcDir = fileURLToPath(new URL('../src/', import.meta.url));
    const offenders: string[] = [];
    const walk = (dir: string) => {
      for (const name of readdirSync(dir)) {
        const path = join(dir, name);
        if (name === 'generated') continue;
        if (statSync(path).isDirectory()) walk(path);
        else if (/\.ts$/.test(name) && /\brawPrisma\b/.test(readFileSync(path, 'utf8'))) {
          offenders.push(relative(srcDir, path));
        }
      }
    };
    walk(srcDir);
    expect(offenders.filter((f) => f !== 'db.ts' && f !== 'main.ts')).toEqual([]);
  });
});
