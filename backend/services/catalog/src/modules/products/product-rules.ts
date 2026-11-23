import { AppError } from '@qc/common';
import type { CatalogConfig } from '@qc/config-schema';

export const MAX_VARIANTS = 50;
export const MAX_IMAGES = 8;

export interface VariantInput {
  id?: string;
  label?: string;
  labelI18n?: Record<string, string> | null;
  options?: Record<string, string>;
  sku?: string | null;
  pricePaise: number;
  mrpPaise?: number | null;
  stockQty?: number | null;
  isAvailable?: boolean;
}

export type CustomFieldValues = Record<string, string | number | boolean>;

interface Issue {
  path: string;
  message: string;
}

/**
 * Checks variants against the shop's variant style and returns them with labels filled in.
 *   single:  exactly one variant (label optional)
 *   units:   one or more, each with a label like "500 g"; no axis options
 *   options: one or more, options only on the shop's axes, unique combinations; label defaults to "M / Red"
 */
export function normalizeVariants(config: CatalogConfig, variants: VariantInput[]): VariantInput[] {
  const issues: Issue[] = [];
  const add = (path: string, message: string) => issues.push({ path, message });

  if (variants.length === 0) add('variants', 'At least one variant is required');
  if (variants.length > MAX_VARIANTS) add('variants', `At most ${MAX_VARIANTS} variants`);
  if (config.variantStyle === 'single' && variants.length > 1) add('variants', 'This shop sells products in a single variant');

  const seenIds = new Set<string>();
  const seenCombos = new Set<string>();
  const result = variants.map((variant, index) => {
    const at = `variants.${index}`;
    const options = variant.options ?? {};
    let label = variant.label?.trim() ?? '';

    if (variant.id) {
      if (seenIds.has(variant.id)) add(`${at}.id`, 'Duplicate variant id');
      seenIds.add(variant.id);
    }
    if (variant.mrpPaise != null && variant.mrpPaise < variant.pricePaise) add(`${at}.mrpPaise`, 'MRP cannot be below the price');

    if (config.variantStyle === 'options') {
      const keys = Object.keys(options);
      if (keys.length === 0) add(`${at}.options`, `Choose at least one of: ${config.variantAxes.join(', ')}`);
      for (const key of keys) {
        if (!(config.variantAxes as string[]).includes(key)) add(`${at}.options.${key}`, 'Not an option this shop uses');
      }
      const combo = JSON.stringify(config.variantAxes.map((axis) => options[axis]?.trim().toLowerCase() ?? ''));
      if (keys.length > 0 && seenCombos.has(combo)) add(`${at}.options`, 'Another variant has the same options');
      seenCombos.add(combo);
      if (!label) label = config.variantAxes.map((axis) => options[axis]?.trim()).filter(Boolean).join(' / ');
    } else {
      if (Object.keys(options).length > 0) add(`${at}.options`, 'Options are only used by shops with option variants');
      if (config.variantStyle === 'units') {
        if (!label) add(`${at}.label`, 'Enter a unit, e.g. "500 g" or "1 pack"');
        const key = label.toLowerCase();
        if (label && seenCombos.has(key)) add(`${at}.label`, 'Another variant has the same unit');
        seenCombos.add(key);
      }
    }
    return { ...variant, label, options };
  });

  if (issues.length > 0) throw new AppError('PRODUCT_INVALID_VARIANTS', 400, 'Check the product variants', issues);
  return result;
}

/** Validates values against the shop's custom field definitions; unknown keys are rejected. */
export function validateCustomFields(config: CatalogConfig, values: CustomFieldValues): CustomFieldValues {
  const issues: Issue[] = [];
  const fields = new Map(config.customFields.map((f) => [f.key, f]));
  const clean: CustomFieldValues = {};

  for (const [key, value] of Object.entries(values)) {
    const field = fields.get(key);
    if (!field) {
      issues.push({ path: `customFields.${key}`, message: 'Unknown field' });
      continue;
    }
    if (value === '' ) continue; // empty text = not set
    const ok =
      (field.type === 'text' && typeof value === 'string' && value.length <= 500) ||
      (field.type === 'number' && typeof value === 'number' && Number.isFinite(value)) ||
      (field.type === 'boolean' && typeof value === 'boolean') ||
      (field.type === 'select' && typeof value === 'string' && (field.options ?? []).includes(value));
    if (!ok) issues.push({ path: `customFields.${key}`, message: `Expected ${field.type === 'select' ? `one of ${field.options!.join(', ')}` : `a ${field.type}`}` });
    else clean[key] = typeof value === 'string' ? value.trim() : value;
  }
  for (const field of config.customFields) {
    if (field.required && clean[field.key] === undefined) issues.push({ path: `customFields.${field.key}`, message: 'Required' });
  }

  if (issues.length > 0) throw new AppError('PRODUCT_INVALID_CUSTOM_FIELDS', 400, 'Check the product details', issues);
  return clean;
}

/** Lower-cased text the trigram index searches: names in every language, tags, text custom fields. */
export function buildSearchText(input: {
  name: string;
  nameI18n?: Record<string, string> | null;
  tags?: string[];
  customFields?: CustomFieldValues;
}): string {
  const parts = [
    input.name,
    ...Object.values(input.nameI18n ?? {}),
    ...(input.tags ?? []),
    ...Object.values(input.customFields ?? {}).filter((v): v is string => typeof v === 'string'),
  ];
  return normalizeSearch(parts.join(' '));
}

export function normalizeSearch(text: string): string {
  return text.normalize('NFC').toLowerCase().replace(/\s+/g, ' ').trim();
}
