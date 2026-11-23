import { Errors, requireShopId } from '@qc/common';
import { runtimeConfigSchema, type ClientConfig, type RuntimeConfig } from '@qc/config-schema';
import type { Db } from '../../db.js';
import type { Prisma, Shop } from '../../generated/prisma/client.js';

/** Minimal shop reference the gateway caches to resolve X-Shop-Key. */
export interface ShopRef {
  id: string;
  slug: string;
  isActive: boolean;
}

export interface PublicShopConfig extends RuntimeConfig {
  id: string;
  slug: string;
}

function toRuntimeConfig(shop: Shop): RuntimeConfig {
  // Re-validate on read: JSON columns are only as safe as the last writer.
  return runtimeConfigSchema.parse({
    shop: {
      name: shop.name,
      ...(shop.nameI18n ? { nameI18n: shop.nameI18n } : {}),
      businessType: shop.businessType,
      currency: shop.currency,
      timezone: shop.timezone,
      contact: shop.contact,
    },
    delivery: shop.delivery,
    payments: shop.payments,
    features: shop.features,
    catalog: shop.catalog,
  });
}

function toShopColumns(config: ClientConfig) {
  return {
    name: config.shop.name,
    nameI18n: (config.shop.nameI18n ?? undefined) as Prisma.InputJsonValue | undefined,
    businessType: config.shop.businessType,
    currency: config.shop.currency,
    timezone: config.shop.timezone,
    contact: config.shop.contact as Prisma.InputJsonValue,
    delivery: config.delivery as Prisma.InputJsonValue,
    payments: config.payments as Prisma.InputJsonValue,
    features: config.features as Prisma.InputJsonValue,
    catalog: config.catalog as Prisma.InputJsonValue,
  };
}

export function createShopsService(db: Db) {
  return {
    async findRefBySlug(slug: string): Promise<ShopRef | null> {
      return db.shop.findUnique({ where: { slug }, select: { id: true, slug: true, isActive: true } });
    },

    /** Runtime config of the shop in the current request context. */
    async getCurrentConfig(): Promise<PublicShopConfig> {
      const shop = await db.shop.findUnique({ where: { id: requireShopId() } });
      if (!shop) throw Errors.notFound('SHOP_NOT_FOUND', 'Shop not found');
      return { id: shop.id, slug: shop.slug, ...toRuntimeConfig(shop) };
    },

    /** Used by the client CLI: create or update a shop from a validated client.json. */
    async upsertFromClientConfig(config: ClientConfig): Promise<ShopRef> {
      const columns = toShopColumns(config);
      return db.shop.upsert({
        where: { slug: config.slug },
        create: { slug: config.slug, ...columns },
        update: columns,
        select: { id: true, slug: true, isActive: true },
      });
    },
  };
}

export type ShopsService = ReturnType<typeof createShopsService>;
