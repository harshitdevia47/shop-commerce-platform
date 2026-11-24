import { z } from 'zod';
import { PRESETS } from './presets.js';
import {
  BUSINESS_TYPES,
  clientConfigSchema,
  type BusinessType,
  type ClientConfig,
  type RuntimeConfig,
} from './schema.js';

export * from './schema.js';
export { PRESETS, type Preset } from './presets.js';

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Objects merge recursively; arrays and scalars from `override` replace `base`. */
export function deepMerge(base: unknown, override: unknown): unknown {
  if (!isPlainObject(base) || !isPlainObject(override)) return override === undefined ? base : override;
  const result: Record<string, unknown> = { ...base };
  for (const [key, value] of Object.entries(override)) result[key] = deepMerge(base[key], value);
  return result;
}

function businessTypeOf(raw: unknown): BusinessType | undefined {
  if (!isPlainObject(raw) || !isPlainObject(raw.shop)) return undefined;
  const type = raw.shop.businessType;
  return (BUSINESS_TYPES as readonly unknown[]).includes(type) ? (type as BusinessType) : undefined;
}

/** Applies the business-type preset under the raw client.json, then validates. */
export function safeParseClientConfig(raw: unknown) {
  const type = businessTypeOf(raw);
  const merged = type ? deepMerge(structuredClone(PRESETS[type]), raw) : raw;
  return clientConfigSchema.safeParse(merged);
}

export function parseClientConfig(raw: unknown): ClientConfig {
  const result = safeParseClientConfig(raw);
  if (!result.success) throw new Error(`Invalid client config:\n${z.prettifyError(result.error)}`);
  return result.data;
}

/** The part of the client config stored by the tenant service and served to the app at runtime. */
export function toRuntimeConfig(config: ClientConfig): RuntimeConfig {
  return {
    shop: config.shop,
    delivery: config.delivery,
    payments: config.payments,
    features: config.features,
    catalog: config.catalog,
    returns: config.returns,
  };
}
