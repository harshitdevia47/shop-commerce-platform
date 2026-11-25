import { z } from 'zod';

/** Shop slug: lowercase, digits, single underscores. Also used as the Android flavor name and X-Shop-Key. */
export const SLUG_PATTERN = /^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/;

export const LOCALES = ['en', 'gu', 'hi'] as const;
export const BUSINESS_TYPES = ['grocery', 'clothing', 'bakery', 'electronics', 'pharmacy', 'general'] as const;
export const FEATURE_KEYS = [
  'deliverySlots',
  'storePickup',
  'returns',
  'prescriptionUpload',
  'orderNotes',
  'handwrittenListUpload',
] as const;
export const VARIANT_STYLES = ['single', 'units', 'options'] as const;
export const VARIANT_AXES = ['size', 'color', 'material', 'flavour', 'storage'] as const;
export const CUSTOM_FIELD_TYPES = ['text', 'number', 'boolean', 'select'] as const;

export type Locale = (typeof LOCALES)[number];
export type BusinessType = (typeof BUSINESS_TYPES)[number];
export type FeatureKey = (typeof FEATURE_KEYS)[number];

const hexColor = z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Expected a colour like #1B5E20');
const paise = z.number().int().nonnegative();
const indianPhone = z.string().regex(/^\+91[6-9]\d{9}$/, 'Expected an Indian mobile number like +919876543210');

/** Translations for shop-entered text; English/default lives in the sibling field. */
export const i18nTextSchema = z
  .object({ en: z.string().min(1), gu: z.string().min(1), hi: z.string().min(1) })
  .partial()
  .strict();

/** Labels shown in UI: English required, others optional. */
export const labelSchema = z
  .object({ en: z.string().min(1), gu: z.string().min(1).optional(), hi: z.string().min(1).optional() })
  .strict();

// ---- Build-time (Flutter) ----

export const buildSchema = z
  .object({
    appName: z.string().min(1).max(30),
    androidPackage: z
      .string()
      .regex(/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/, 'Expected a package id like in.yourco.shopname'),
    iosBundleId: z
      .string()
      .regex(/^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*)+$/)
      .optional(),
    version: z.string().regex(/^\d+\.\d+\.\d+\+\d+$/, 'Expected a version like 1.0.0+1'),
  })
  .strict();

export const brandingSchema = z
  .object({
    logo: z.string().min(1).default('logo.png'),
    icon: z.string().min(1).default('icon.png'),
    colors: z
      .object({
        primary: hexColor,
        secondary: hexColor,
        surface: hexColor.optional(),
      })
      .strict(),
  })
  .strict();

export const localeSchema = z
  .object({
    default: z.enum(LOCALES),
    supported: z.array(z.enum(LOCALES)).min(1),
  })
  .strict()
  .refine((value) => value.supported.includes(value.default), {
    message: 'locale.default must be one of locale.supported',
    path: ['default'],
  });

// ---- Runtime (synced to tenant service DB, served by GET /shop/config) ----

export const shopSchema = z
  .object({
    name: z.string().min(1).max(60),
    nameI18n: i18nTextSchema.optional(),
    businessType: z.enum(BUSINESS_TYPES),
    currency: z.literal('INR').default('INR'),
    timezone: z.literal('Asia/Kolkata').default('Asia/Kolkata'),
    contact: z
      .object({
        phone: indianPhone,
        whatsapp: indianPhone.optional(),
        address: z.string().min(1),
        lat: z.number().min(-90).max(90),
        lng: z.number().min(-180).max(180),
      })
      .strict(),
  })
  .strict();

const clockTime = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected a time like 09:00');

/** Delivery windows customers choose from (same every day, shop timezone). Used when features.deliverySlots is on. */
export const slotsSchema = z
  .object({
    windows: z
      .array(z.object({ start: clockTime, end: clockTime }).strict().refine((w) => w.start < w.end, { message: 'end must be after start' }))
      .min(1)
      .max(12),
    /** Days offered, starting today. */
    daysAhead: z.number().int().min(1).max(7).default(2),
    /** Orders per window. */
    capacityPerSlot: z.number().int().min(1).max(500).default(10),
    /** A window closes this many minutes before it starts. */
    cutoffMinutes: z.number().int().min(0).max(24 * 60).default(60),
  })
  .strict();

export const deliverySchema = z
  .object({
    enabled: z.boolean(),
    radiusKm: z.number().positive().max(50),
    /** Empty list = any pincode within radius. */
    pincodes: z.array(z.string().regex(/^\d{6}$/)),
    minOrderPaise: paise,
    feePaise: paise,
    /** null = delivery fee always charged. */
    freeAbovePaise: paise.nullable(),
    etaMinutes: z.number().int().positive().max(24 * 60),
    slots: slotsSchema.optional(),
  })
  .strict();

/** Returns / exchanges policy (used when features.returns is on). */
export const returnsSchema = z
  .object({
    /** Days after delivery a customer may ask. */
    windowDays: z.number().int().min(1).max(60).default(7),
    allowExchange: z.boolean().default(true),
  })
  .strict();

const DEFAULT_RETURNS = { windowDays: 7, allowExchange: true };

/** Owner's switch: stop taking new orders for a while (holiday, stock-taking). Runtime only. */
export const orderingSchema = z
  .object({
    paused: z.boolean().default(false),
    /** Shown to customers while paused, e.g. "Closed for Diwali, back on 3 Nov". */
    pausedMessage: z.string().trim().max(200).optional(),
  })
  .strict();

export const paymentsSchema = z
  .object({
    cod: z.boolean(),
    upi: z
      .object({
        enabled: z.boolean(),
        vpa: z
          .string()
          .regex(/^[A-Za-z0-9._-]{2,256}@[A-Za-z]{2,64}$/, 'Expected a UPI ID like shop@okaxis')
          .optional(),
        payeeName: z.string().min(1).max(50).optional(),
      })
      .strict()
      .refine((upi) => !upi.enabled || (upi.vpa && upi.payeeName), {
        message: 'upi.vpa and upi.payeeName are required when UPI is enabled',
      }),
    razorpay: z.object({ enabled: z.boolean() }).strict(),
  })
  .strict()
  .refine((p) => p.cod || p.upi.enabled || p.razorpay.enabled, {
    message: 'At least one payment method must be enabled',
  });

export const featuresSchema = z
  .object({
    deliverySlots: z.boolean(),
    storePickup: z.boolean(),
    returns: z.boolean(),
    prescriptionUpload: z.boolean(),
    orderNotes: z.boolean(),
    handwrittenListUpload: z.boolean(),
  })
  .strict();

export const customFieldSchema = z
  .object({
    key: z.string().regex(/^[a-z][a-zA-Z0-9]{0,39}$/, 'Expected a camelCase key'),
    type: z.enum(CUSTOM_FIELD_TYPES),
    label: labelSchema,
    required: z.boolean().default(false),
    options: z.array(z.string().min(1)).min(1).optional(),
  })
  .strict()
  .refine((field) => (field.type === 'select') === (field.options !== undefined), {
    message: 'options is required for select fields and not allowed otherwise',
    path: ['options'],
  });

export const catalogSchema = z
  .object({
    variantStyle: z.enum(VARIANT_STYLES),
    variantAxes: z.array(z.enum(VARIANT_AXES)),
    customFields: z.array(customFieldSchema),
  })
  .strict()
  .refine((c) => c.variantStyle !== 'options' || c.variantAxes.length > 0, {
    message: 'variantAxes must not be empty when variantStyle is "options"',
    path: ['variantAxes'],
  })
  .refine((c) => new Set(c.customFields.map((f) => f.key)).size === c.customFields.length, {
    message: 'customFields keys must be unique',
    path: ['customFields'],
  });

interface RuntimeParts {
  delivery: z.infer<typeof deliverySchema>;
  features: z.infer<typeof featuresSchema>;
}

/** Cross-section rules shared by the runtime and full client schemas. */
function checkCrossSectionRules(config: RuntimeParts, ctx: z.RefinementCtx): void {
  if (!config.delivery.enabled && !config.features.storePickup) {
    ctx.addIssue({
      code: 'custom',
      message: 'Enable delivery or the storePickup feature, otherwise customers cannot receive orders',
      path: ['delivery', 'enabled'],
    });
  }
  if (config.features.deliverySlots && !config.delivery.enabled) {
    ctx.addIssue({
      code: 'custom',
      message: 'deliverySlots requires delivery.enabled',
      path: ['features', 'deliverySlots'],
    });
  }
  if (config.features.deliverySlots && !config.delivery.slots) {
    ctx.addIssue({
      code: 'custom',
      message: 'deliverySlots requires delivery.slots (windows customers choose from)',
      path: ['delivery', 'slots'],
    });
  }
}

export const runtimeConfigSchema = z
  .object({
    shop: shopSchema,
    delivery: deliverySchema,
    payments: paymentsSchema,
    features: featuresSchema,
    catalog: catalogSchema,
    returns: returnsSchema.default(DEFAULT_RETURNS),
    ordering: orderingSchema.default({ paused: false }),
  })
  .strict()
  .superRefine(checkCrossSectionRules);

export const clientConfigSchema = z
  .object({
    $schema: z.string().optional(),
    slug: z.string().regex(SLUG_PATTERN, 'Expected a slug like sharma_kirana'),
    build: buildSchema,
    branding: brandingSchema,
    locale: localeSchema,
    shop: shopSchema,
    delivery: deliverySchema,
    payments: paymentsSchema,
    features: featuresSchema,
    catalog: catalogSchema,
    returns: returnsSchema.default(DEFAULT_RETURNS),
  })
  .strict()
  .superRefine(checkCrossSectionRules);

export type ClientConfig = z.infer<typeof clientConfigSchema>;
export type RuntimeConfig = z.infer<typeof runtimeConfigSchema>;
export type Features = z.infer<typeof featuresSchema>;
export type DeliveryConfig = z.infer<typeof deliverySchema>;
export type PaymentsConfig = z.infer<typeof paymentsSchema>;
export type CatalogConfig = z.infer<typeof catalogSchema>;
export type SlotsConfig = z.infer<typeof slotsSchema>;
export type ReturnsConfig = z.infer<typeof returnsSchema>;
export type OrderingConfig = z.infer<typeof orderingSchema>;
export type ShopInfo = z.infer<typeof shopSchema>;
