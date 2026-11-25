import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createLogger, findRawPrismaOffenders, getContext, signInternalHeaders, type Role } from '@qc/common';
import { PRESETS, type CatalogConfig } from '@qc/config-schema';
import type { Express } from 'express';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { createCatalogApp } from '../src/app.js';
import { createDb } from '../src/db.js';
import type { MediaRef } from '../src/upstreams.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const SHOP_A = randomUUID(); // grocery: unit variants
const SHOP_B = randomUUID(); // clothing: size/color options
const SHOPS = [SHOP_A, SHOP_B];

const configs: Record<string, CatalogConfig> = {
  [SHOP_A]: PRESETS.grocery.catalog,
  [SHOP_B]: PRESETS.clothing.catalog,
};
/** Fake media service: media id -> owning shop. */
const mediaOwners = new Map<string, string>(); // media id -> shop id
function newMedia(shopId: string): string {
  const id = randomUUID();
  mediaOwners.set(id, shopId);
  return id;
}

let app: Express;

function as(shopId: string, role: Role | null = 'OWNER') {
  return signInternalHeaders(
    { requestId: randomUUID(), shopId, userId: role ? randomUUID() : undefined, role: role ?? undefined },
    SECRET,
  );
}
const admin = (shopId: string = SHOP_A) => as(shopId, 'OWNER');
const guest = (shopId: string = SHOP_A) => as(shopId, null);

async function createCategory(shopId: string, body: Record<string, unknown>) {
  const res = await request(app).post('/api/v1/admin/catalog/categories').set(admin(shopId)).send(body);
  expect(res.status, JSON.stringify(res.body)).toBe(201);
  return res.body.data as { id: string };
}

const rice = (extra: Record<string, unknown> = {}) => ({
  name: 'Basmati Rice',
  nameI18n: { gu: 'બાસમતી ચોખા', hi: 'बासमती चावल' },
  customFields: { brand: 'India Gate' },
  tags: ['chawal'],
  variants: [
    { label: '1 kg', pricePaise: 12000, mrpPaise: 14000, stockQty: 10 },
    { label: '5 kg', pricePaise: 55000 },
  ],
  ...extra,
});

async function createProduct(shopId: string, body: Record<string, unknown>) {
  const res = await request(app).post('/api/v1/admin/catalog/products').set(admin(shopId)).send(body);
  expect(res.status, JSON.stringify(res.body)).toBe(201);
  return res.body.data;
}

beforeAll(() => {
  app = createCatalogApp({
    db,
    logger: createLogger('catalog-test', 'silent'),
    internalSecret: SECRET,
    settings: { get: async () => configs[getContext()!.shopId!]! },
    media: {
      resolve: async (ids): Promise<MediaRef[]> =>
        ids
          .filter((id) => mediaOwners.get(id) === getContext()!.shopId)
          .map((id) => ({ id, url: `/media/x/${id}-full.webp`, thumbUrl: `/media/x/${id}-thumb.webp` })),
    },
  });
});

async function clean() {
  const where = { shopId: { in: SHOPS } };
  await rawPrisma.stockReservation.deleteMany({ where });
  await rawPrisma.productImage.deleteMany({ where });
  await rawPrisma.variant.deleteMany({ where });
  await rawPrisma.product.deleteMany({ where });
  await rawPrisma.category.updateMany({ where, data: { parentId: null } });
  await rawPrisma.category.deleteMany({ where });
}

beforeEach(clean);
afterAll(async () => {
  await clean();
  await rawPrisma.$disconnect();
});

describe('categories', () => {
  it('admin creates a two-level tree; customers see only active ones', async () => {
    const dairy = await createCategory(SHOP_A, { name: 'Dairy', nameI18n: { gu: 'ડેરી' }, sortOrder: 1 });
    await createCategory(SHOP_A, { name: 'Milk', parentId: dairy.id });
    const hidden = await createCategory(SHOP_A, { name: 'Seasonal', isActive: false });
    await createCategory(SHOP_A, { name: 'Under hidden', parentId: hidden.id });

    const res = await request(app).get('/api/v1/catalog/categories').set(guest());
    expect(res.status).toBe(200);
    expect(res.body.data.map((c: { name: string }) => c.name)).toEqual(['Milk', 'Dairy']);
    expect(res.body.data[1].nameI18n).toEqual({ gu: 'ડેરી' });

    const all = await request(app).get('/api/v1/admin/catalog/categories').set(admin());
    expect(all.body.data).toHaveLength(4);
  });

  it('refuses a third level and self-parenting', async () => {
    const a = await createCategory(SHOP_A, { name: 'A' });
    const b = await createCategory(SHOP_A, { name: 'B', parentId: a.id });
    const third = await request(app).post('/api/v1/admin/catalog/categories').set(admin()).send({ name: 'C', parentId: b.id });
    expect(third.body.error.code).toBe('CATEGORY_PARENT_INVALID');
    const self = await request(app).patch(`/api/v1/admin/catalog/categories/${a.id}`).set(admin()).send({ parentId: a.id });
    expect(self.body.error.code).toBe('CATEGORY_PARENT_INVALID');
  });

  it('delete is refused while products remain, then soft-deletes', async () => {
    const cat = await createCategory(SHOP_A, { name: 'Grains' });
    const product = await createProduct(SHOP_A, rice({ categoryId: cat.id }));
    const blocked = await request(app).delete(`/api/v1/admin/catalog/categories/${cat.id}`).set(admin());
    expect(blocked.status).toBe(409);
    expect(blocked.body.error).toMatchObject({ code: 'CATEGORY_NOT_EMPTY', details: { products: 1 } });

    await request(app).delete(`/api/v1/admin/catalog/products/${product.id}`).set(admin()).expect(204);
    await request(app).delete(`/api/v1/admin/catalog/categories/${cat.id}`).set(admin()).expect(204);
    expect((await rawPrisma.category.findUniqueOrThrow({ where: { id: cat.id } })).deletedAt).not.toBeNull();
  });

  it('stores the thumbnail URL of an image from the same shop only', async () => {
    const ok = await createCategory(SHOP_A, { name: 'Fruits', imageMediaId: newMedia(SHOP_A) });
    expect((await rawPrisma.category.findUniqueOrThrow({ where: { id: ok.id } })).imageUrl).toMatch(/-thumb\.webp$/);
    const foreign = await request(app)
      .post('/api/v1/admin/catalog/categories')
      .set(admin())
      .send({ name: 'X', imageMediaId: newMedia(SHOP_B) });
    expect(foreign.body.error.code).toBe('MEDIA_NOT_FOUND');
  });

  it('admin routes need an admin', async () => {
    expect((await request(app).post('/api/v1/admin/catalog/categories').set(as(SHOP_A, 'CUSTOMER')).send({ name: 'X' })).status).toBe(403);
    expect((await request(app).get('/api/v1/admin/catalog/categories').set(guest())).status).toBe(401);
    expect((await request(app).get('/api/v1/admin/catalog/categories').set(as(SHOP_A, 'STAFF'))).status).toBe(200);
  });
});

describe('products (admin)', () => {
  it('creates a grocery product with unit variants, custom fields and images', async () => {
    const media = [newMedia(SHOP_A), newMedia(SHOP_A)];
    const product = await createProduct(SHOP_A, rice({ imageMediaIds: media }));
    expect(product).toMatchObject({
      name: 'Basmati Rice',
      customFields: { brand: 'India Gate' },
      isActive: true,
      inStock: true,
      images: [{ mediaId: media[0] }, { mediaId: media[1] }],
      variants: [
        { label: '1 kg', pricePaise: 12000, mrpPaise: 14000, stockQty: 10, inStock: true },
        { label: '5 kg', pricePaise: 55000, mrpPaise: null, stockQty: null, inStock: true },
      ],
    });
  });

  it('validates variants against the shop variant style', async () => {
    const noUnit = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin())
      .send(rice({ variants: [{ pricePaise: 100 }] }));
    expect(noUnit.body.error.code).toBe('PRODUCT_INVALID_VARIANTS');

    const options = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin())
      .send(rice({ variants: [{ label: '1 kg', options: { size: 'M' }, pricePaise: 100 }] }));
    expect(options.body.error.code).toBe('PRODUCT_INVALID_VARIANTS');

    const mrp = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin())
      .send(rice({ variants: [{ label: '1 kg', pricePaise: 500, mrpPaise: 400 }] }));
    expect(mrp.body.error.details[0]).toMatchObject({ path: 'variants.0.mrpPaise' });

    const money = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin())
      .send(rice({ variants: [{ label: '1 kg', pricePaise: 10.5 }] }));
    expect(money.body.error.code).toBe('VALIDATION_FAILED');
  });

  it('clothing shop: option variants get labels and must be unique', async () => {
    const shirt = await createProduct(SHOP_B, {
      name: 'Cotton Shirt',
      customFields: { fabric: 'Cotton', gender: 'men' },
      variants: [
        { options: { size: 'M', color: 'Blue' }, pricePaise: 79900 },
        { options: { size: 'L', color: 'Blue' }, pricePaise: 79900 },
      ],
    });
    expect(shirt.variants.map((v: { label: string }) => v.label)).toEqual(['M / Blue', 'L / Blue']);

    const dupe = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin(SHOP_B))
      .send({ name: 'Dupe', variants: [{ options: { size: 'M' }, pricePaise: 1 }, { options: { size: 'm' }, pricePaise: 1 }] });
    expect(dupe.body.error.code).toBe('PRODUCT_INVALID_VARIANTS');

    const axis = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin(SHOP_B))
      .send({ name: 'Bad', variants: [{ options: { flavour: 'Mango' }, pricePaise: 1 }] });
    expect(axis.body.error.details[0].path).toBe('variants.0.options.flavour');
  });

  it('validates custom fields against shop config', async () => {
    const unknown = await request(app).post('/api/v1/admin/catalog/products').set(admin()).send(rice({ customFields: { colour: 'red' } }));
    expect(unknown.body.error.code).toBe('PRODUCT_INVALID_CUSTOM_FIELDS');
    const select = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin(SHOP_B))
      .send({ name: 'Kurta', customFields: { gender: 'aliens' }, variants: [{ options: { size: 'M' }, pricePaise: 1 }] });
    expect(select.body.error.code).toBe('PRODUCT_INVALID_CUSTOM_FIELDS');
  });

  it('replace updates kept variants, adds new ones and soft-deletes the rest', async () => {
    const product = await createProduct(SHOP_A, rice());
    const [oneKg, fiveKg] = product.variants;
    const res = await request(app)
      .put(`/api/v1/admin/catalog/products/${product.id}`)
      .set(admin())
      .send(
        rice({
          name: 'Basmati Rice Premium',
          variants: [
            { id: oneKg.id, label: '1 kg', pricePaise: 12500 },
            { label: '10 kg', pricePaise: 100000 },
          ],
        }),
      );
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body.data.name).toBe('Basmati Rice Premium');
    expect(res.body.data.variants.map((v: { label: string; pricePaise: number }) => [v.label, v.pricePaise])).toEqual([
      ['1 kg', 12500],
      ['10 kg', 100000],
    ]);
    expect(res.body.data.variants[0].id).toBe(oneKg.id);
    expect((await rawPrisma.variant.findUniqueOrThrow({ where: { id: fiveKg.id } })).deletedAt).not.toBeNull();
  });

  it("replace refuses another product's variant id", async () => {
    const a = await createProduct(SHOP_A, rice());
    const b = await createProduct(SHOP_A, rice({ name: 'Sugar' }));
    const res = await request(app)
      .put(`/api/v1/admin/catalog/products/${a.id}`)
      .set(admin())
      .send(rice({ variants: [{ id: b.variants[0].id, label: '1 kg', pricePaise: 1 }] }));
    expect(res.body.error.code).toBe('PRODUCT_INVALID_VARIANTS');
  });

  it('quick-edits a variant and toggles a product', async () => {
    const product = await createProduct(SHOP_A, rice());
    const variantId = product.variants[0].id;
    const res = await request(app).patch(`/api/v1/admin/catalog/variants/${variantId}`).set(admin()).send({ isAvailable: false });
    expect(res.body.data.variants[0]).toMatchObject({ isAvailable: false, inStock: false });
    const bad = await request(app).patch(`/api/v1/admin/catalog/variants/${variantId}`).set(admin()).send({ pricePaise: 20000 });
    expect(bad.body.error.code).toBe('PRODUCT_INVALID_VARIANTS'); // MRP 14000 < new price

    await request(app).patch(`/api/v1/admin/catalog/products/${product.id}`).set(admin()).send({ isActive: false }).expect(200);
    expect((await request(app).get(`/api/v1/catalog/products/${product.id}`).set(guest())).status).toBe(404);
  });

  it('admin list filters by status', async () => {
    await createProduct(SHOP_A, rice());
    await createProduct(SHOP_A, rice({ name: 'Old stock', isActive: false }));
    const inactive = await request(app).get('/api/v1/admin/catalog/products?status=inactive').set(admin());
    expect(inactive.body.data.map((p: { name: string }) => p.name)).toEqual(['Old stock']);
    const all = await request(app).get('/api/v1/admin/catalog/products').set(admin());
    expect(all.body.data).toHaveLength(2);
  });
});

describe('internal: product count for the platform', () => {
  it('counts products that are not deleted, per shop', async () => {
    const count = async (shop: string) => (await request(app).get('/internal/stats/products').set(guest(shop))).body.data;
    const before = (await count(SHOP_A)).count;
    const product = await createProduct(SHOP_A, rice());
    expect(await count(SHOP_A)).toEqual({ count: before + 1 });
    const other = (await count(SHOP_B)).count;
    await request(app).delete(`/api/v1/admin/catalog/products/${product.id}`).set(admin()).expect(204);
    expect(await count(SHOP_A)).toEqual({ count: before });
    expect((await count(SHOP_B)).count).toBe(other);
  });
});

describe('products (customer browsing)', () => {
  it('hides stock counts and SKUs', async () => {
    const product = await createProduct(SHOP_A, rice());
    const res = await request(app).get(`/api/v1/catalog/products/${product.id}`).set(guest());
    expect(res.status).toBe(200);
    expect(res.body.data.variants[0]).not.toHaveProperty('stockQty');
    expect(res.body.data.variants[0]).not.toHaveProperty('sku');
    expect(res.body.data).not.toHaveProperty('isActive');
  });

  it('out of stock when tracked stock is zero', async () => {
    const product = await createProduct(SHOP_A, rice({ variants: [{ label: '1 kg', pricePaise: 100, stockQty: 0 }] }));
    const res = await request(app).get(`/api/v1/catalog/products/${product.id}`).set(guest());
    expect(res.body.data).toMatchObject({ inStock: false, variants: [{ inStock: false }] });
  });

  it('paginates with a cursor', async () => {
    for (let i = 0; i < 5; i++) await createProduct(SHOP_A, rice({ name: `P${i}`, sortOrder: i }));
    const first = await request(app).get('/api/v1/catalog/products?limit=2').set(guest());
    expect(first.body.data.map((p: { name: string }) => p.name)).toEqual(['P0', 'P1']);
    expect(first.body.nextCursor).toBeTruthy();
    const second = await request(app).get(`/api/v1/catalog/products?limit=2&cursor=${first.body.nextCursor}`).set(guest());
    expect(second.body.data.map((p: { name: string }) => p.name)).toEqual(['P2', 'P3']);
    const last = await request(app).get(`/api/v1/catalog/products?limit=2&cursor=${second.body.nextCursor}`).set(guest());
    expect(last.body).toMatchObject({ data: [{ name: 'P4' }], nextCursor: null });
  });

  it('searches names in every language, tags and brand, case-insensitively', async () => {
    await createProduct(SHOP_A, rice());
    await createProduct(SHOP_A, rice({ name: 'Toor Dal', nameI18n: { gu: 'તુવેર દાળ' }, tags: [], customFields: {} }));
    const search = async (q: string) =>
      (await request(app).get('/api/v1/catalog/products').query({ q }).set(guest())).body.data.map((p: { name: string }) => p.name);
    expect(await search('BASMATI')).toEqual(['Basmati Rice']);
    expect(await search('ચોખા')).toEqual(['Basmati Rice']);
    expect(await search('चावल')).toEqual(['Basmati Rice']);
    expect(await search('chawal')).toEqual(['Basmati Rice']);
    expect(await search('india gate')).toEqual(['Basmati Rice']);
    expect(await search('દાળ')).toEqual(['Toor Dal']);
    expect(await search('%')).toHaveLength(2); // wildcards are not special
    expect(await search('zzz')).toEqual([]);
  });

  it('filters by category including sub-categories; hides products of hidden categories', async () => {
    const staples = await createCategory(SHOP_A, { name: 'Staples' });
    const rices = await createCategory(SHOP_A, { name: 'Rice', parentId: staples.id });
    const hidden = await createCategory(SHOP_A, { name: 'Hidden', isActive: false });
    await createProduct(SHOP_A, rice({ categoryId: rices.id }));
    await createProduct(SHOP_A, rice({ name: 'Secret', categoryId: hidden.id }));
    await createProduct(SHOP_A, rice({ name: 'Loose' }));

    const inStaples = await request(app).get(`/api/v1/catalog/products?categoryId=${staples.id}`).set(guest());
    expect(inStaples.body.data.map((p: { name: string }) => p.name)).toEqual(['Basmati Rice']);
    const all = await request(app).get('/api/v1/catalog/products').set(guest());
    expect(all.body.data.map((p: { name: string }) => p.name).sort()).toEqual(['Basmati Rice', 'Loose']);
  });
});

describe('tenant isolation', () => {
  it("shop B cannot see, edit or delete shop A's catalog", async () => {
    const cat = await createCategory(SHOP_A, { name: 'Dairy' });
    const product = await createProduct(SHOP_A, rice({ categoryId: cat.id }));
    const variantId = product.variants[0].id;

    expect((await request(app).get(`/api/v1/catalog/products/${product.id}`).set(guest(SHOP_B))).status).toBe(404);
    expect((await request(app).get(`/api/v1/admin/catalog/products/${product.id}`).set(admin(SHOP_B))).status).toBe(404);
    expect((await request(app).get('/api/v1/catalog/products').set(guest(SHOP_B))).body.data).toEqual([]);
    expect((await request(app).get('/api/v1/catalog/categories').set(guest(SHOP_B))).body.data).toEqual([]);
    expect((await request(app).put(`/api/v1/admin/catalog/products/${product.id}`).set(admin(SHOP_B)).send({ name: 'x', variants: [{ options: { size: 'M' }, pricePaise: 1 }] })).status).toBe(404);
    expect((await request(app).patch(`/api/v1/admin/catalog/variants/${variantId}`).set(admin(SHOP_B)).send({ pricePaise: 1 })).status).toBe(404);
    expect((await request(app).patch(`/api/v1/admin/catalog/categories/${cat.id}`).set(admin(SHOP_B)).send({ name: 'x' })).status).toBe(404);
    expect((await request(app).delete(`/api/v1/admin/catalog/products/${product.id}`).set(admin(SHOP_B))).status).toBe(404);
    expect((await request(app).delete(`/api/v1/admin/catalog/categories/${cat.id}`).set(admin(SHOP_B))).status).toBe(404);

    // Linking to another shop's category or images is refused.
    const link = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin(SHOP_B))
      .send({ name: 'x', categoryId: cat.id, variants: [{ options: { size: 'M' }, pricePaise: 1 }] });
    expect(link.body.error.code).toBe('CATEGORY_NOT_FOUND');
    const images = await request(app)
      .post('/api/v1/admin/catalog/products')
      .set(admin(SHOP_B))
      .send({ name: 'x', imageMediaIds: [newMedia(SHOP_A)], variants: [{ options: { size: 'M' }, pricePaise: 1 }] });
    expect(images.body.error.code).toBe('MEDIA_NOT_FOUND');

    // Still intact for shop A.
    const mine = await request(app).get(`/api/v1/admin/catalog/products/${product.id}`).set(admin());
    expect(mine.body.data.name).toBe('Basmati Rice');
  });

  it('the database refuses cross-shop parent links even without the service checks', async () => {
    const cat = await createCategory(SHOP_A, { name: 'Dairy' });
    await expect(
      rawPrisma.product.create({ data: { shopId: SHOP_B, categoryId: cat.id, name: 'x', searchText: 'x' } }),
    ).rejects.toThrow();
  });
});

describe('rawPrisma usage guard', () => {
  it('is only referenced in db.ts and main.ts within src/', () => {
    expect(findRawPrismaOffenders(fileURLToPath(new URL('../src/', import.meta.url)))).toEqual([]);
  });
});
