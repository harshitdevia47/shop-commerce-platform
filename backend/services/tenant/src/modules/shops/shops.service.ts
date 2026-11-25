import { AppError, Errors, requireShopId } from '@qc/common';
import { runtimeConfigSchema, type ClientConfig, type RuntimeConfig } from '@qc/config-schema';
import { z } from 'zod';
import type { Db } from '../../db.js';
import { Prisma, type Shop } from '../../generated/prisma/client.js';

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
    ...(shop.returns ? { returns: shop.returns } : {}),
    ...(shop.ordering ? { ordering: shop.ordering } : {}),
  });
}

/**
 * What the owner may change in the app. Branding, catalog shape and Razorpay (needs server keys)
 * stay with the platform team.
 */
export const ownerSettingsPatchSchema = z
  .object({
    contact: z
      .object({
        phone: z.string(),
        whatsapp: z.string().nullable(),
        address: z.string(),
        lat: z.number(),
        lng: z.number(),
      })
      .partial()
      .strict(),
    delivery: z
      .object({
        enabled: z.boolean(),
        radiusKm: z.number(),
        pincodes: z.array(z.string()),
        minOrderPaise: z.number(),
        feePaise: z.number(),
        freeAbovePaise: z.number().nullable(),
        etaMinutes: z.number(),
        slots: z.unknown().nullable(),
      })
      .partial()
      .strict(),
    payments: z
      .object({
        cod: z.boolean(),
        upi: z.object({ enabled: z.boolean(), vpa: z.string().optional(), payeeName: z.string().optional() }).strict(),
      })
      .partial()
      .strict(),
    features: z
      .object({
        deliverySlots: z.boolean(),
        storePickup: z.boolean(),
        returns: z.boolean(),
        prescriptionUpload: z.boolean(),
        orderNotes: z.boolean(),
        handwrittenListUpload: z.boolean(),
      })
      .partial()
      .strict(),
    returns: z.object({ windowDays: z.number(), allowExchange: z.boolean() }).partial().strict(),
    ordering: z.object({ paused: z.boolean(), pausedMessage: z.string().nullable() }).partial().strict(),
  })
  .partial()
  .strict();

export type OwnerSettingsPatch = z.infer<typeof ownerSettingsPatchSchema>;

/** Applies the owner's changes on top of the current settings (each value then re-validated as a whole). */
function applyPatch(current: RuntimeConfig, patch: OwnerSettingsPatch): unknown {
  const { whatsapp, ...contact } = patch.contact ?? {};
  const { slots, ...delivery } = patch.delivery ?? {};
  const { pausedMessage, ...ordering } = patch.ordering ?? {};
  const mergedContact = { ...current.shop.contact, ...contact };
  if (whatsapp === null) delete mergedContact.whatsapp;
  else if (whatsapp !== undefined) mergedContact.whatsapp = whatsapp;
  const mergedDelivery: Record<string, unknown> = { ...current.delivery, ...delivery };
  if (slots === null) delete mergedDelivery.slots;
  else if (slots !== undefined) mergedDelivery.slots = slots;
  const mergedOrdering: Record<string, unknown> = { ...current.ordering, ...ordering };
  if (pausedMessage === null || pausedMessage === '') delete mergedOrdering.pausedMessage;
  else if (pausedMessage !== undefined) mergedOrdering.pausedMessage = pausedMessage;
  return {
    ...current,
    shop: { ...current.shop, contact: mergedContact },
    delivery: mergedDelivery,
    payments: {
      ...current.payments,
      ...(patch.payments?.cod !== undefined ? { cod: patch.payments.cod } : {}),
      ...(patch.payments?.upi ? { upi: patch.payments.upi } : {}),
    },
    features: { ...current.features, ...patch.features },
    returns: { ...current.returns, ...patch.returns },
    ordering: mergedOrdering,
  };
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
    returns: config.returns as Prisma.InputJsonValue,
  };
}

export function createShopsService(db: Db, now: () => Date = () => new Date()) {
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

    /** Owner: change shop settings from the app. The whole result is validated like client.json. */
    async updateOwnerSettings(patch: OwnerSettingsPatch): Promise<PublicShopConfig> {
      const shop = await db.shop.findUnique({ where: { id: requireShopId() } });
      if (!shop) throw Errors.notFound('SHOP_NOT_FOUND', 'Shop not found');
      const parsed = runtimeConfigSchema.safeParse(applyPatch(toRuntimeConfig(shop), patch));
      if (!parsed.success) {
        throw new AppError('SETTINGS_INVALID', 400, 'Some settings are not valid', {
          issues: parsed.error.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
        });
      }
      const next = parsed.data;
      const updated = await db.shop.update({
        where: { id: shop.id },
        data: {
          contact: next.shop.contact as Prisma.InputJsonValue,
          delivery: next.delivery as Prisma.InputJsonValue,
          payments: next.payments as Prisma.InputJsonValue,
          features: next.features as Prisma.InputJsonValue,
          returns: next.returns as Prisma.InputJsonValue,
          ordering: next.ordering as Prisma.InputJsonValue,
          settingsEditedAt: now(),
        },
      });
      return { id: updated.id, slug: updated.slug, ...toRuntimeConfig(updated) };
    },

    /**
     * Used by the client CLI: create or update a shop from a validated client.json.
     * Once the owner has edited settings in the app, client.json only updates the shop name,
     * business type and catalog shape, unless `resetSettings` (the platform overwrites everything).
     */
    async upsertFromClientConfig(config: ClientConfig, options: { resetSettings?: boolean } = {}): Promise<ShopRef & { keptOwnerSettings: boolean }> {
      const columns = toShopColumns(config);
      const existing = await db.shop.findUnique({ where: { slug: config.slug }, select: { settingsEditedAt: true } });
      const keep = !!existing?.settingsEditedAt && !options.resetSettings;
      const update = keep
        ? {
            name: columns.name,
            nameI18n: columns.nameI18n,
            businessType: columns.businessType,
            currency: columns.currency,
            timezone: columns.timezone,
            catalog: columns.catalog,
          }
        : { ...columns, ...(options.resetSettings ? { settingsEditedAt: null, ordering: Prisma.DbNull } : {}) };
      const shop = await db.shop.upsert({
        where: { slug: config.slug },
        create: { slug: config.slug, ...columns },
        update,
        select: { id: true, slug: true, isActive: true },
      });
      return { ...shop, keptOwnerSettings: keep };
    },
  };
}

export type ShopsService = ReturnType<typeof createShopsService>;
