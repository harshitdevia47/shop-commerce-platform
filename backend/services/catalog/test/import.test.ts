import { randomUUID } from 'node:crypto';
import { createLogger, getContext, signInternalHeaders, type Role } from '@qc/common';
import { PRESETS, type CatalogConfig } from '@qc/config-schema';
import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createCatalogApp } from '../src/app.js';
import { createDb } from '../src/db.js';
import { normalizeHeader, parseAmount } from '../src/modules/import/import.service.js';

const SECRET = process.env.INTERNAL_HMAC_SECRET!;
const { rawPrisma, db } = createDb(process.env.DATABASE_URL!);
const SHOP_A = randomUUID(); // grocery: sizes
const SHOP_B = randomUUID(); // clothing: size/color options
const configs: Record<string, CatalogConfig> = { [SHOP_A]: PRESETS.grocery.catalog, [SHOP_B]: PRESETS.clothing.catalog };
const app = createCatalogApp({
  db,
  logger: createLogger('catalog-test', 'silent'),
  internalSecret: SECRET,
  settings: { get: async () => configs[getContext()!.shopId!]! },
  media: { resolve: async () => [] },
});

const as = (shopId = SHOP_A, role: Role = 'OWNER') => signInternalHeaders({ requestId: randomUUID(), shopId, userId: randomUUID(), role }, SECRET);
const send = (rows: string[][], dryRun: boolean, headers = as()) =>
  request(app).post('/api/v1/admin/catalog/import').set(headers).send({ rows, dryRun });
const products = (shopId = SHOP_A) =>
  rawPrisma.product.findMany({ where: { shopId, deletedAt: null }, include: { variants: { where: { deletedAt: null }, orderBy: { sortOrder: 'asc' } }, category: true }, orderBy: { name: 'asc' } });

const HEADER = ['Category', 'Name', 'Name GU', 'Size', 'Price (₹)', 'MRP', 'Stock', 'Brand', 'Tags', 'Notes'];
const SHEET = [
  HEADER,
  ['Rice & Grains', 'Basmati Rice', 'બાસમતી ચોખા', '1 kg', '110', '125', '40', 'India Gate', 'chawal, rice', 'x'],
  ['Rice & Grains', 'basmati rice', '', '5 kg', '₹520', '600', '', '', '', ''],
  ['', '', '', '', '', '', '', '', '', ''], // blank line in Excel
  ['Oil', 'Groundnut Oil', '', '1 L', '1,250.50', '', '12', 'Tirupati', '', ''],
];

async function clean() {
  const where = { shopId: { in: [SHOP_A, SHOP_B] } };
  await rawPrisma.variant.deleteMany({ where });
  await rawPrisma.product.deleteMany({ where });
  await rawPrisma.category.deleteMany({ where });
}
beforeEach(clean);
afterAll(async () => {
  await clean();
  await rawPrisma.$disconnect();
});

describe('helpers', () => {
  it('reads headers and amounts the way people type them', () => {
    expect(normalizeHeader('Price (₹)')).toBe('price');
    expect(normalizeHeader(' Name GU ')).toBe('name_gu');
    expect(parseAmount('₹1,250.50')).toBe(125050);
    expect(parseAmount('Rs. 45')).toBe(4500);
    expect(parseAmount('12.345')).toBeNull();
    expect(parseAmount('free')).toBeNull();
  });
});

describe('product import', () => {
  it('previews without saving, then imports products, sizes and new categories', async () => {
    const preview = await send(SHEET, true);
    expect(preview.status, JSON.stringify(preview.body)).toBe(200);
    expect(preview.body.data).toMatchObject({
      rows: 3,
      newProducts: 2,
      updatedProducts: 0,
      newVariants: 3,
      newCategories: ['Rice & Grains', 'Oil'],
      ignoredColumns: ['Notes'],
      errorCount: 0,
      imported: false,
    });
    expect(await products()).toHaveLength(0);

    const done = await send(SHEET, false);
    expect(done.body.data.imported).toBe(true);
    const all = await products();
    const rice = all.find((p) => p.name === 'Basmati Rice');
    const oil = all.find((p) => p.name === 'Groundnut Oil');
    expect(rice!.name).toBe('Basmati Rice');
    expect(rice!.nameI18n).toEqual({ gu: 'બાસમતી ચોખા' });
    expect(rice!.category!.name).toBe('Rice & Grains');
    expect(rice!.tags).toEqual(['chawal', 'rice']);
    expect(rice!.customFields).toEqual({ brand: 'India Gate' });
    expect(rice!.searchText).toContain('બાસમતી');
    expect(rice!.variants.map((v) => [v.label, v.pricePaise, v.mrpPaise, v.stockQty])).toEqual([
      ['1 kg', 11000, 12500, 40],
      ['5 kg', 52000, 60000, null],
    ]);
    expect(oil!.variants[0]!.pricePaise).toBe(125050);
  });

  it('a second file updates prices and stock of the same products instead of duplicating them', async () => {
    await send(SHEET, false);
    const update = [
      ['name', 'size', 'price', 'stock'],
      ['BASMATI RICE', '1 kg', '115', ''], // empty stock keeps 40
      ['Basmati Rice', '10 kg', '990', '5'], // new size
    ];
    const preview = (await send(update, true)).body.data;
    expect(preview).toMatchObject({ newProducts: 0, updatedProducts: 1, newVariants: 1, updatedVariants: 1, newCategories: [] });
    await send(update, false);
    const rice = (await products()).find((p) => p.name === 'Basmati Rice')!;
    expect(rice.category!.name).toBe('Rice & Grains'); // no category column: unchanged
    expect(rice.variants.map((v) => [v.label, v.pricePaise, v.stockQty])).toEqual([
      ['1 kg', 11500, 40],
      ['5 kg', 52000, null],
      ['10 kg', 99000, 5],
    ]);
  });

  it('reports every problem with its row and column, and imports nothing', async () => {
    const bad = [
      HEADER,
      ['Snacks', 'Chips', '', '100 g', 'twenty', '', '', '', '', ''],
      ['Snacks', 'Namkeen', '', '', '40', '30', '-2', '', '', ''],
      ['Snacks', '', '', '1 kg', '40', '', '', '', '', ''],
      ['Snacks', 'Biscuits', '', '1 pack', '10', '', '', '', '', ''],
      ['Snacks', 'biscuits', '', '1 Pack', '12', '', '', '', '', ''],
    ];
    const preview = (await send(bad, true)).body.data;
    expect(preview.errors).toEqual([
      { row: 2, column: 'Price (₹)', code: 'PRICE_INVALID' },
      { row: 3, column: 'MRP', code: 'MRP_BELOW_PRICE' },
      { row: 3, column: 'Stock', code: 'STOCK_INVALID' },
      { row: 3, column: 'Size', code: 'SIZE_REQUIRED' },
      { row: 4, column: 'Name', code: 'NAME_REQUIRED' },
      { row: 6, code: 'DUPLICATE_ROW' },
    ]);
    const res = await send(bad, false);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('IMPORT_INVALID');
    expect(res.body.error.details.errorCount).toBe(6);
    expect(await products()).toHaveLength(0);
  });

  it('refuses files without the needed columns or rows', async () => {
    const res = await send([['Item', 'Rate']], true);
    expect(res.body.error).toMatchObject({ code: 'IMPORT_COLUMNS_MISSING', details: { missing: ['size'] } });
    expect((await send([['name', 'size', 'price'], ['', '', '']], true)).body.error.code).toBe('IMPORT_EMPTY');
  });

  it('option shops use their own columns (size, color) and custom fields like gender', async () => {
    const sheet = [
      ['Name', 'Size', 'Color', 'Price', 'Gender'],
      ['Cotton T-Shirt', 'M', 'Red', '399', 'Men'],
      ['Cotton T-Shirt', 'L', 'Red', '449', ''],
    ];
    const res = await send(sheet, false, as(SHOP_B));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    const [shirt] = await products(SHOP_B);
    expect(shirt!.variants.map((v) => v.label)).toEqual(['M / Red', 'L / Red']);
    expect(shirt!.customFields).toEqual({ gender: 'men' });
    expect((await send([['Name', 'Price'], ['Shirt', '10']], true, as(SHOP_B))).body.error.code).toBe('IMPORT_COLUMNS_MISSING');
  });

  it('serves a template with this shop columns; staff may import, customers may not; shops stay apart', async () => {
    const template = (await request(app).get('/api/v1/admin/catalog/import/template').set(as())).body.data;
    expect(template.columns).toEqual(['category', 'name', 'name_gu', 'name_hi', 'size', 'price', 'mrp', 'stock', 'brand', 'description', 'tags']);
    expect(template.rows).toHaveLength(2);
    expect((await request(app).get('/api/v1/admin/catalog/import/template').set(as(SHOP_B))).body.data.columns).toContain('color');

    expect((await send(SHEET, true, as(SHOP_A, 'CUSTOMER'))).status).toBe(403);
    expect((await send(SHEET, false, as(SHOP_A, 'STAFF'))).status).toBe(200);
    expect(await products(SHOP_B)).toHaveLength(0);
    // Shop B importing the same names creates its own products.
    await send([['name', 'size', 'color', 'price'], ['Basmati Rice', 'M', 'Red', '1']], false, as(SHOP_B));
    expect((await products(SHOP_A)).length).toBe(2);
    expect((await products(SHOP_B)).length).toBe(1);
  });
});
