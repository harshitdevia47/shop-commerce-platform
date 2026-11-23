import { AppError, Errors, requireShopId, toPage, type Page } from '@qc/common';
import type { Db } from '../../db.js';
import { Prisma } from '../../generated/prisma/client.js';
import type { MediaResolver, ShopCatalogSettings } from '../../upstreams.js';
import { i18nJson, type CategoriesService } from '../categories/categories.service.js';
import {
  MAX_IMAGES,
  buildSearchText,
  normalizeSearch,
  normalizeVariants,
  validateCustomFields,
  type CustomFieldValues,
  type VariantInput,
} from './product-rules.js';

type I18n = Record<string, string> | null;

export interface ProductInput {
  name: string;
  nameI18n?: I18n;
  description?: string | null;
  descriptionI18n?: I18n;
  categoryId?: string | null;
  customFields?: CustomFieldValues;
  tags?: string[];
  imageMediaIds?: string[];
  isActive?: boolean;
  sortOrder?: number;
  variants: VariantInput[];
}

export interface VariantPatch {
  pricePaise?: number;
  mrpPaise?: number | null;
  stockQty?: number | null;
  isAvailable?: boolean;
}

export interface ProductQuery {
  categoryId?: string;
  q?: string;
  cursor?: string;
  limit: number;
  /** Admin only. */
  status?: 'active' | 'inactive' | 'all';
}

const withChildren = {
  variants: { where: { deletedAt: null }, orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] },
  images: { orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] },
} satisfies Prisma.ProductInclude;

type ProductRow = Prisma.ProductGetPayload<{ include: typeof withChildren }>;
type VariantRow = ProductRow['variants'][number];

const inStock = (v: VariantRow) => v.isAvailable && (v.stockQty === null || v.stockQty > 0);

function publicVariant(v: VariantRow) {
  return {
    id: v.id,
    label: v.label,
    labelI18n: (v.labelI18n as I18n) ?? null,
    options: v.options as Record<string, string>,
    pricePaise: v.pricePaise,
    mrpPaise: v.mrpPaise,
    inStock: inStock(v),
  };
}

/** What customers see. Stock counts and SKUs stay private. */
export function toPublicProduct(p: ProductRow) {
  return {
    id: p.id,
    categoryId: p.categoryId,
    name: p.name,
    nameI18n: (p.nameI18n as I18n) ?? null,
    description: p.description,
    descriptionI18n: (p.descriptionI18n as I18n) ?? null,
    customFields: p.customFields as CustomFieldValues,
    tags: p.tags,
    images: p.images.map((i) => ({ mediaId: i.mediaId, url: i.url, thumbUrl: i.thumbUrl })),
    variants: p.variants.map(publicVariant),
    inStock: p.variants.some(inStock),
  };
}

export function toAdminProduct(p: ProductRow) {
  return {
    ...toPublicProduct(p),
    isActive: p.isActive,
    sortOrder: p.sortOrder,
    updatedAt: p.updatedAt,
    variants: p.variants.map((v) => ({
      ...publicVariant(v),
      sku: v.sku,
      stockQty: v.stockQty,
      isAvailable: v.isAvailable,
    })),
  };
}

export type PublicProduct = ReturnType<typeof toPublicProduct>;
export type AdminProduct = ReturnType<typeof toAdminProduct>;

/** LIKE wildcards are stripped so user input is always matched literally. */
const searchTerm = (q: string) => normalizeSearch(q.replace(/[%_\\]/g, ' '));

export interface ProductsServiceDeps {
  db: Db;
  categories: CategoriesService;
  settings: ShopCatalogSettings;
  media: MediaResolver;
  now?: () => Date;
}

export function createProductsService({ db, categories, settings, media, now = () => new Date() }: ProductsServiceDeps) {
  async function find(id: string, onlyVisible: boolean): Promise<ProductRow> {
    const product = await db.product.findFirst({
      where: { id, deletedAt: null, ...(onlyVisible ? { isActive: true } : {}) },
      include: withChildren,
    });
    if (!product) throw Errors.notFound('PRODUCT_NOT_FOUND', 'Product not found');
    return product;
  }

  async function list(query: ProductQuery, visibleOnly: boolean): Promise<ProductRow[]> {
    const where: Prisma.ProductWhereInput = { deletedAt: null };
    if (visibleOnly) {
      where.isActive = true;
      // Hide products of hidden or deleted categories.
      where.OR = [{ categoryId: null }, { category: { isActive: true, deletedAt: null } }];
    } else if (query.status === 'active') where.isActive = true;
    else if (query.status === 'inactive') where.isActive = false;
    if (query.categoryId) where.categoryId = { in: await categories.withChildren(query.categoryId) };
    const term = query.q ? searchTerm(query.q) : '';
    if (term) where.searchText = { contains: term };

    return db.product.findMany({
      where,
      include: withChildren,
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
      take: query.limit + 1,
      ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
    });
  }

  /** Validates everything that depends on the shop's settings or other rows, before any write. */
  async function prepare(input: ProductInput) {
    const config = await settings.get();
    const variants = normalizeVariants(config, input.variants);
    const customFields = validateCustomFields(config, input.customFields ?? {});

    if (input.categoryId) await categories.get(input.categoryId);

    const mediaIds = [...new Set(input.imageMediaIds ?? [])];
    if (mediaIds.length > MAX_IMAGES) throw Errors.badRequest('PRODUCT_TOO_MANY_IMAGES', `At most ${MAX_IMAGES} images`);
    const found = new Map((await media.resolve(mediaIds)).map((m) => [m.id, m]));
    const missing = mediaIds.filter((id) => !found.has(id));
    if (missing.length > 0) throw new AppError('MEDIA_NOT_FOUND', 400, 'Some images were not found', { missing });
    const images = mediaIds.map((id, sortOrder) => ({ mediaId: id, url: found.get(id)!.url, thumbUrl: found.get(id)!.thumbUrl, sortOrder }));

    const tags = [...new Set((input.tags ?? []).map((t) => t.trim()).filter(Boolean))];
    const columns = {
      name: input.name,
      nameI18n: i18nJson(input.nameI18n),
      description: input.description ?? null,
      descriptionI18n: i18nJson(input.descriptionI18n),
      categoryId: input.categoryId ?? null,
      customFields: customFields as Prisma.InputJsonValue,
      tags,
      searchText: buildSearchText({ name: input.name, nameI18n: input.nameI18n, tags, customFields }),
      isActive: input.isActive ?? true,
      sortOrder: input.sortOrder ?? 0,
    };
    return { columns, variants, images };
  }

  const variantColumns = (v: VariantInput, sortOrder: number) => ({
    label: v.label ?? '',
    labelI18n: i18nJson(v.labelI18n),
    options: (v.options ?? {}) as Prisma.InputJsonValue,
    sku: v.sku ?? null,
    pricePaise: v.pricePaise,
    mrpPaise: v.mrpPaise ?? null,
    stockQty: v.stockQty ?? null,
    isAvailable: v.isAvailable ?? true,
    sortOrder,
  });

  return {
    async listPublic(query: ProductQuery): Promise<Page<PublicProduct>> {
      return toPage(await list(query, true), query.limit, (p) => p.id, toPublicProduct);
    },

    async listAdmin(query: ProductQuery): Promise<Page<AdminProduct>> {
      return toPage(await list(query, false), query.limit, (p) => p.id, toAdminProduct);
    },

    getPublic: async (id: string) => toPublicProduct(await find(id, true)),
    getAdmin: async (id: string) => toAdminProduct(await find(id, false)),

    async create(input: ProductInput): Promise<AdminProduct> {
      const shopId = requireShopId();
      const { columns, variants, images } = await prepare(input);
      const id = await db.$transaction(async (tx) => {
        const product = await tx.product.create({ data: { shopId, ...columns } });
        await tx.variant.createMany({
          data: variants.map((v, i) => ({ shopId, productId: product.id, ...variantColumns(v, i) })),
        });
        if (images.length > 0) {
          await tx.productImage.createMany({ data: images.map((img) => ({ shopId, productId: product.id, ...img })) });
        }
        return product.id;
      });
      return toAdminProduct(await find(id, false));
    },

    /**
     * Saves the whole product form. Variants with an `id` are updated, new ones created, and
     * variants left out are soft-deleted (orders keep their snapshots). Images are replaced.
     */
    async replace(id: string, input: ProductInput): Promise<AdminProduct> {
      const shopId = requireShopId();
      const existing = await find(id, false);
      const { columns, variants, images } = await prepare(input);

      const existingIds = new Set(existing.variants.map((v) => v.id));
      const unknown = variants.filter((v) => v.id && !existingIds.has(v.id));
      if (unknown.length > 0) {
        throw new AppError('PRODUCT_INVALID_VARIANTS', 400, 'Check the product variants', unknown.map((v) => ({ path: 'variants', message: `Unknown variant ${v.id}` })));
      }
      const keptIds = new Set(variants.flatMap((v) => (v.id ? [v.id] : [])));

      await db.$transaction(async (tx) => {
        await tx.product.update({ where: { id }, data: columns });
        await tx.variant.updateMany({
          where: { productId: id, deletedAt: null, id: { notIn: [...keptIds] } },
          data: { deletedAt: now() },
        });
        for (const [index, variant] of variants.entries()) {
          if (variant.id) await tx.variant.update({ where: { id: variant.id }, data: variantColumns(variant, index) });
          else await tx.variant.create({ data: { shopId, productId: id, ...variantColumns(variant, index) } });
        }
        await tx.productImage.deleteMany({ where: { productId: id } });
        if (images.length > 0) {
          await tx.productImage.createMany({ data: images.map((img) => ({ shopId, productId: id, ...img })) });
        }
      });
      return toAdminProduct(await find(id, false));
    },

    async setActive(id: string, isActive: boolean): Promise<AdminProduct> {
      await find(id, false);
      await db.product.update({ where: { id }, data: { isActive } });
      return toAdminProduct(await find(id, false));
    },

    async remove(id: string): Promise<void> {
      await find(id, false);
      const deletedAt = now();
      await db.$transaction(async (tx) => {
        await tx.product.update({ where: { id }, data: { deletedAt } });
        await tx.variant.updateMany({ where: { productId: id, deletedAt: null }, data: { deletedAt } });
      });
    },

    /** Quick edit from the product list: price, MRP, stock, in/out of stock. */
    async updateVariant(variantId: string, patch: VariantPatch): Promise<AdminProduct> {
      const variant = await db.variant.findFirst({ where: { id: variantId, deletedAt: null } });
      if (!variant) throw Errors.notFound('VARIANT_NOT_FOUND', 'Variant not found');
      const price = patch.pricePaise ?? variant.pricePaise;
      const mrp = patch.mrpPaise === undefined ? variant.mrpPaise : patch.mrpPaise;
      if (mrp !== null && mrp < price) {
        throw new AppError('PRODUCT_INVALID_VARIANTS', 400, 'Check the product variants', [{ path: 'mrpPaise', message: 'MRP cannot be below the price' }]);
      }
      await db.variant.update({ where: { id: variantId }, data: patch });
      return toAdminProduct(await find(variant.productId, false));
    },
  };
}

export type ProductsService = ReturnType<typeof createProductsService>;
