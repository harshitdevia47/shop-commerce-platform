import { AppError, requireShopId, uuidv7 } from '@qc/common';
import type { CatalogConfig } from '@qc/config-schema';

type CustomFieldDef = CatalogConfig['customFields'][number];
import type { Db } from '../../db.js';
import { Prisma } from '../../generated/prisma/client.js';
import type { ShopCatalogSettings } from '../../upstreams.js';
import { MAX_VARIANTS, buildSearchText, normalizeVariants, validateCustomFields, type CustomFieldValues, type VariantInput } from '../products/product-rules.js';

/**
 * Bulk product import from a spreadsheet (Excel/CSV, turned into rows by the app).
 *
 * One row = one sellable size/option of a product; rows with the same product name form one
 * product. Existing products (same name, any case) are matched, not duplicated: their matching
 * sizes get the new price/MRP/stock, new sizes are added, nothing is removed, and names, photos and
 * descriptions stay as they are. Missing categories are created. All or nothing: any row problem
 * refuses the whole import, and a dry run reports everything first.
 */

export const MAX_IMPORT_ROWS = 2000;
const MAX_REPORTED_ERRORS = 200;
const MAX_PAISE = 100_000_000;

export type RowErrorCode =
  | 'NAME_REQUIRED'
  | 'NAME_TOO_LONG'
  | 'PRICE_INVALID'
  | 'MRP_INVALID'
  | 'MRP_BELOW_PRICE'
  | 'STOCK_INVALID'
  | 'SIZE_REQUIRED'
  | 'OPTION_REQUIRED'
  | 'DUPLICATE_ROW'
  | 'DUPLICATE_PRODUCT'
  | 'TOO_MANY_VARIANTS'
  | 'FIELD_INVALID'
  | 'FIELD_REQUIRED';

export interface RowError {
  /** Spreadsheet row number (the header is row 1). */
  row: number;
  /** Column header as written in the file, when the problem is in one cell. */
  column?: string;
  code: RowErrorCode;
}

export interface ImportSummary {
  rows: number;
  newProducts: number;
  updatedProducts: number;
  newVariants: number;
  updatedVariants: number;
  newCategories: string[];
  /** Headers we did not recognise (their cells were not imported). */
  ignoredColumns: string[];
  errors: RowError[];
  errorCount: number;
  imported: boolean;
}

/** "Price (₹)" → "price", "Name GU" → "name_gu". */
export function normalizeHeader(header: string): string {
  return header
    .toLowerCase()
    .replace(/\(.*?\)/g, ' ')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

const ALIASES: Record<string, string[]> = {
  category: ['category', 'category_name', 'group', 'section'],
  name: ['name', 'product', 'product_name', 'item', 'item_name', 'name_en'],
  name_gu: ['name_gu', 'gujarati', 'gujarati_name', 'name_gujarati'],
  name_hi: ['name_hi', 'hindi', 'hindi_name', 'name_hindi'],
  size: ['size', 'unit', 'pack', 'pack_size', 'weight', 'variant'],
  price: ['price', 'selling_price', 'sale_price', 'rate', 'sp'],
  mrp: ['mrp', 'max_price'],
  stock: ['stock', 'stock_qty', 'qty', 'quantity', 'in_stock'],
  description: ['description', 'details', 'about'],
  tags: ['tags', 'keywords', 'search_words'],
};

/** Paise from "120", "₹1,200.50", "Rs. 45"; null when not a valid amount. */
export function parseAmount(text: string): number | null {
  const clean = text.replace(/₹|rs\.?|inr|,|\s/gi, '');
  const match = /^(\d{1,7})(?:\.(\d{1,2}))?$/.exec(clean);
  if (!match) return null;
  const paise = Number(match[1]) * 100 + Number((match[2] ?? '').padEnd(2, '0'));
  return paise <= MAX_PAISE ? paise : null;
}

function parseCustomValue(field: CustomFieldDef, text: string): string | number | boolean | undefined {
  switch (field.type) {
    case 'text':
      return text;
    case 'number': {
      const n = Number(text.replace(/,/g, ''));
      return Number.isFinite(n) ? n : undefined;
    }
    case 'boolean': {
      const v = text.toLowerCase();
      if (['yes', 'y', 'true', '1', 'हाँ', 'હા'].includes(v)) return true;
      if (['no', 'n', 'false', '0', 'नहीं', 'ના'].includes(v)) return false;
      return undefined;
    }
    case 'select':
      return (field.options ?? []).find((o) => o.toLowerCase() === text.toLowerCase());
  }
}

interface ParsedRow {
  row: number;
  category: string;
  name: string;
  nameI18n: Record<string, string>;
  variant: VariantInput;
  /** Stock cell was empty (keeps the stock of an existing size). */
  stockBlank: boolean;
  customFields: CustomFieldValues;
  description: string;
  tags: string[];
}

/** Template the app offers for download: this shop's columns and two example rows. */
export function importTemplate(config: CatalogConfig): { columns: string[]; rows: string[][] } {
  const optionCols = config.variantStyle === 'options' ? config.variantAxes.map((a) => a.toLowerCase()) : [];
  const sizeCol = config.variantStyle === 'options' ? [] : ['size'];
  const custom = config.customFields.map((f) => f.key);
  const columns = ['category', 'name', 'name_gu', 'name_hi', ...sizeCol, ...optionCols, 'price', 'mrp', 'stock', ...custom, 'description', 'tags'];
  const example = (values: Record<string, string>) => columns.map((c) => values[c] ?? '');
  const sample = (row: number): Record<string, string> => {
    if (config.variantStyle === 'options') {
      const opts = Object.fromEntries(optionCols.map((c, i) => [c, [['M', 'Red'], ['L', 'Red']][row]?.[i] ?? 'Free']));
      return { category: 'T-Shirts', name: 'Cotton T-Shirt', ...opts, price: row ? '449' : '399', mrp: '599', stock: '10' };
    }
    if (config.variantStyle === 'single') {
      return { category: 'Stationery', name: row ? 'Ball Pen (Blue)' : 'Notebook 200 pages', size: '', price: row ? '10' : '60', mrp: row ? '10' : '70', stock: '' };
    }
    return {
      category: 'Rice & Grains',
      name: 'Basmati Rice',
      name_gu: 'બાસમતી ચોખા',
      name_hi: 'बासमती चावल',
      size: row ? '5 kg' : '1 kg',
      price: row ? '520' : '110',
      mrp: row ? '600' : '125',
      stock: row ? '' : '40',
      tags: 'chawal, rice',
    };
  };
  return { columns, rows: [example(sample(0)), example(sample(1))] };
}

export function createImportService(db: Db, settings: ShopCatalogSettings) {
  return {
    async template() {
      return importTemplate(await settings.get());
    },

    async run(rows: string[][], options: { dryRun: boolean }): Promise<ImportSummary> {
      const config = await settings.get();
      const [header, ...body] = rows;
      if (!header) throw new AppError('IMPORT_EMPTY', 400, 'The file has no rows');

      // ---- Columns ----
      const fieldOf = new Map<number, string>();
      const ignoredColumns: string[] = [];
      const axisByKey = new Map(config.variantAxes.map((a) => [normalizeHeader(a), a]));
      const customByKey = new Map<string, CustomFieldDef>();
      for (const f of config.customFields) {
        customByKey.set(normalizeHeader(f.key), f);
        for (const label of Object.values(f.label)) customByKey.set(normalizeHeader(label), f);
      }
      header.forEach((raw, index) => {
        const key = normalizeHeader(raw ?? '');
        if (!key) return;
        // Option axes ("Size", "Colour") win over the generic size column in option shops.
        if (config.variantStyle === 'options' && axisByKey.has(key)) return fieldOf.set(index, `axis:${axisByKey.get(key)}`);
        const custom = customByKey.get(key);
        if (custom) return fieldOf.set(index, `custom:${custom.key}`);
        const known = Object.entries(ALIASES).find(([, names]) => names.includes(key));
        if (known && !(config.variantStyle === 'options' && known[0] === 'size')) return fieldOf.set(index, known[0]);
        ignoredColumns.push(raw);
      });
      const has = (field: string) => [...fieldOf.values()].includes(field);
      const missing = ['name', 'price', ...(config.variantStyle === 'units' ? ['size'] : [])].filter((f) => !has(f));
      if (config.variantStyle === 'options' && !config.variantAxes.some((a) => has(`axis:${a}`))) missing.push(...config.variantAxes.map((a) => a.toLowerCase()));
      if (missing.length > 0) throw new AppError('IMPORT_COLUMNS_MISSING', 400, `Missing columns: ${missing.join(', ')}`, { missing });

      const dataRows = body.map((cells, i) => ({ cells, row: i + 2 })).filter(({ cells }) => cells.some((c) => (c ?? '').trim() !== ''));
      if (dataRows.length === 0) throw new AppError('IMPORT_EMPTY', 400, 'The file has no products');
      if (dataRows.length > MAX_IMPORT_ROWS) throw new AppError('IMPORT_TOO_LARGE', 400, `At most ${MAX_IMPORT_ROWS} rows per file`, { max: MAX_IMPORT_ROWS });

      const columnName = (field: string) => header[[...fieldOf.entries()].find(([, f]) => f === field)![0]]!;
      const errors: RowError[] = [];
      const fail = (row: number, code: RowErrorCode, field?: string) => errors.push({ row, code, ...(field ? { column: columnName(field) } : {}) });

      // ---- Rows ----
      const parsed: ParsedRow[] = [];
      for (const { cells, row } of dataRows) {
        const cell = (field: string) => {
          const index = [...fieldOf.entries()].find(([, f]) => f === field)?.[0];
          return index === undefined ? '' : (cells[index] ?? '').trim();
        };
        const name = cell('name').replace(/\s+/g, ' ');
        if (!name) fail(row, 'NAME_REQUIRED', 'name');
        else if (name.length > 120) fail(row, 'NAME_TOO_LONG', 'name');

        const pricePaise = parseAmount(cell('price'));
        if (pricePaise === null) fail(row, 'PRICE_INVALID', 'price');
        let mrpPaise: number | null = null;
        if (cell('mrp')) {
          mrpPaise = parseAmount(cell('mrp'));
          if (mrpPaise === null) fail(row, 'MRP_INVALID', 'mrp');
          else if (pricePaise !== null && mrpPaise < pricePaise) fail(row, 'MRP_BELOW_PRICE', 'mrp');
        }
        let stockQty: number | null = null;
        if (cell('stock')) {
          const n = Number(cell('stock').replace(/,/g, ''));
          if (!Number.isInteger(n) || n < 0 || n > 1_000_000) fail(row, 'STOCK_INVALID', 'stock');
          else stockQty = n;
        }

        const variant: VariantInput = { pricePaise: pricePaise ?? 0, mrpPaise, stockQty };
        if (config.variantStyle === 'options') {
          const opts: Record<string, string> = {};
          for (const axis of config.variantAxes) if (cell(`axis:${axis}`)) opts[axis] = cell(`axis:${axis}`).slice(0, 40);
          if (Object.keys(opts).length === 0) fail(row, 'OPTION_REQUIRED');
          variant.options = opts;
        } else {
          const size = cell('size').slice(0, 60);
          if (config.variantStyle === 'units' && !size) fail(row, 'SIZE_REQUIRED', 'size');
          if (size) variant.label = size;
        }

        const customFields: CustomFieldValues = {};
        for (const field of config.customFields) {
          const text = cell(`custom:${field.key}`);
          if (!text) continue;
          const value = parseCustomValue(field, text);
          if (value === undefined) fail(row, 'FIELD_INVALID', `custom:${field.key}`);
          else customFields[field.key] = value;
        }

        const nameI18n: Record<string, string> = {};
        if (cell('name_gu')) nameI18n.gu = cell('name_gu').slice(0, 120);
        if (cell('name_hi')) nameI18n.hi = cell('name_hi').slice(0, 120);
        parsed.push({
          row,
          category: cell('category').slice(0, 60),
          name,
          nameI18n,
          variant,
          stockBlank: !cell('stock'),
          customFields,
          description: cell('description').slice(0, 4000),
          tags: cell('tags').split(/[,;|]/).map((t) => t.trim().slice(0, 40)).filter(Boolean).slice(0, 20),
        });
      }

      // ---- Group into products ----
      const groups = new Map<string, ParsedRow[]>();
      for (const p of parsed) {
        if (!p.name) continue;
        const key = p.name.toLowerCase();
        groups.set(key, [...(groups.get(key) ?? []), p]);
      }

      const existing = await db.product.findMany({
        where: { deletedAt: null },
        select: { id: true, name: true, categoryId: true, variants: { where: { deletedAt: null }, select: { id: true, label: true, sortOrder: true }, orderBy: { sortOrder: 'asc' } } },
      });
      const existingByName = new Map(existing.map((p) => [p.name.toLowerCase(), p]));
      const categories = await db.category.findMany({ where: { deletedAt: null }, select: { id: true, name: true } });
      const categoryByName = new Map(categories.map((c) => [c.name.toLowerCase(), c.id]));
      const newCategories = new Map<string, string>(); // lower → name as written

      interface Plan {
        rows: ParsedRow[];
        existingId?: string;
        categoryName: string;
        create: VariantInput[];
        update: { id: string; variant: VariantInput; stockBlank: boolean }[];
        customFields: CustomFieldValues;
        nextSort: number;
      }
      const plans: Plan[] = [];

      for (const rowsOfProduct of groups.values()) {
        const first = rowsOfProduct[0]!;
        if (config.variantStyle === 'single' && rowsOfProduct.length > 1) {
          for (const r of rowsOfProduct.slice(1)) fail(r.row, 'DUPLICATE_PRODUCT', 'name');
          continue;
        }
        let normalized: VariantInput[];
        try {
          normalized = normalizeVariants(config, rowsOfProduct.map((r) => r.variant));
        } catch (error) {
          if (!(error instanceof AppError)) throw error;
          const issues = (error.details ?? []) as { path: string; message: string }[];
          for (const issue of issues) {
            const index = Number(/^variants\.(\d+)/.exec(issue.path)?.[1]);
            const r = Number.isInteger(index) ? rowsOfProduct[index]! : first;
            // Missing sizes/options and MRP below price are already reported per cell above.
            if (/same/.test(issue.message)) fail(r.row, 'DUPLICATE_ROW');
            else if (issue.path === 'variants' && rowsOfProduct.length > MAX_VARIANTS) fail(r.row, 'TOO_MANY_VARIANTS');
          }
          continue;
        }

        let customFields: CustomFieldValues = {};
        const merged = Object.assign({}, ...rowsOfProduct.map((r) => r.customFields).reverse()) as CustomFieldValues;
        const match = existingByName.get(first.name.toLowerCase());
        if (!match) {
          try {
            customFields = validateCustomFields(config, merged);
          } catch (error) {
            if (!(error instanceof AppError)) throw error;
            for (const issue of (error.details ?? []) as { path: string }[]) {
              const key = issue.path.replace('customFields.', '');
              if (has(`custom:${key}`)) fail(first.row, 'FIELD_REQUIRED', `custom:${key}`);
              else fail(first.row, 'FIELD_REQUIRED');
            }
            continue;
          }
        }

        const categoryName = rowsOfProduct.find((r) => r.category)?.category ?? '';
        if (categoryName && !categoryByName.has(categoryName.toLowerCase())) newCategories.set(categoryName.toLowerCase(), categoryName);

        const plan: Plan = { rows: rowsOfProduct, categoryName, create: [], update: [], customFields, nextSort: 0, ...(match ? { existingId: match.id } : {}) };
        if (match) {
          const byLabel = new Map(match.variants.map((v) => [v.label.toLowerCase(), v.id]));
          plan.nextSort = (match.variants.at(-1)?.sortOrder ?? -1) + 1;
          normalized.forEach((variant, i) => {
            // A single-variant shop has one size per product: always that one.
            const id = config.variantStyle === 'single' ? match.variants[0]?.id : byLabel.get((variant.label ?? '').toLowerCase());
            if (id) plan.update.push({ id, variant, stockBlank: rowsOfProduct[i]!.stockBlank });
            else plan.create.push(variant);
          });
          if (match.variants.length + plan.create.length > MAX_VARIANTS) {
            fail(first.row, 'TOO_MANY_VARIANTS');
            continue;
          }
        } else {
          plan.create = normalized;
        }
        plans.push(plan);
      }

      errors.sort((a, b) => a.row - b.row);
      const summary: ImportSummary = {
        rows: dataRows.length,
        newProducts: plans.filter((p) => !p.existingId).length,
        updatedProducts: plans.filter((p) => p.existingId).length,
        newVariants: plans.reduce((n, p) => n + p.create.length, 0),
        updatedVariants: plans.reduce((n, p) => n + p.update.length, 0),
        newCategories: [...newCategories.values()],
        ignoredColumns,
        errors: errors.slice(0, MAX_REPORTED_ERRORS),
        errorCount: errors.length,
        imported: false,
      };
      if (options.dryRun) return summary;
      if (errors.length > 0) throw new AppError('IMPORT_INVALID', 400, 'Some rows need fixing', summary);

      // ---- Apply (all or nothing) ----
      const shopId = requireShopId();
      await db.$transaction(
        async (tx) => {
          const maxSort = await tx.category.aggregate({ _max: { sortOrder: true }, where: { deletedAt: null } });
          let sort = (maxSort._max.sortOrder ?? 0) + 1;
          for (const [lower, name] of newCategories) {
            const id = uuidv7();
            await tx.category.create({ data: { id, shopId, name, sortOrder: sort++ } });
            categoryByName.set(lower, id);
          }
          const categoryIdOf = (name: string) => (name ? (categoryByName.get(name.toLowerCase()) ?? null) : null);

          const newProducts: Prisma.ProductCreateManyInput[] = [];
          const newVariants: Prisma.VariantCreateManyInput[] = [];
          for (const plan of plans) {
            const first = plan.rows[0]!;
            const productId = plan.existingId ?? uuidv7();
            if (!plan.existingId) {
              const nameI18n = Object.assign({}, ...plan.rows.map((r) => r.nameI18n).reverse()) as Record<string, string>;
              const tags = [...new Set(plan.rows.flatMap((r) => r.tags))].slice(0, 20);
              newProducts.push({
                id: productId,
                shopId,
                name: first.name,
                nameI18n: Object.keys(nameI18n).length ? nameI18n : Prisma.DbNull,
                description: plan.rows.find((r) => r.description)?.description || null,
                categoryId: categoryIdOf(plan.categoryName),
                customFields: plan.customFields as Prisma.InputJsonValue,
                tags,
                searchText: buildSearchText({ name: first.name, nameI18n, tags, customFields: plan.customFields }),
              });
            } else if (plan.categoryName) {
              await tx.product.update({ where: { id: productId }, data: { categoryId: categoryIdOf(plan.categoryName) } });
            }
            plan.create.forEach((v, i) =>
              newVariants.push({
                shopId,
                productId,
                label: v.label ?? '',
                options: (v.options ?? {}) as Prisma.InputJsonValue,
                pricePaise: v.pricePaise,
                mrpPaise: v.mrpPaise ?? null,
                stockQty: v.stockQty ?? null,
                sortOrder: plan.nextSort + i,
              }),
            );
            for (const u of plan.update) {
              await tx.variant.update({
                where: { id: u.id },
                data: {
                  pricePaise: u.variant.pricePaise,
                  mrpPaise: u.variant.mrpPaise ?? null,
                  // An empty stock cell keeps the current stock of an existing size.
                  ...(u.stockBlank ? {} : { stockQty: u.variant.stockQty ?? null }),
                },
              });
            }
          }
          if (newProducts.length) await tx.product.createMany({ data: newProducts });
          if (newVariants.length) await tx.variant.createMany({ data: newVariants });
        },
        { timeout: 60_000, maxWait: 10_000 },
      );
      return { ...summary, imported: true };
    },
  };
}

export type ImportService = ReturnType<typeof createImportService>;
