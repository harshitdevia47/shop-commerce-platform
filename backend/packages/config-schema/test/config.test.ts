import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { PRESETS, deepMerge, parseClientConfig, safeParseClientConfig, toRuntimeConfig } from '../src/index.js';

const clientsDir = fileURLToPath(new URL('../../../../clients/', import.meta.url));
const load = (slug: string): Record<string, unknown> =>
  JSON.parse(readFileSync(`${clientsDir}${slug}/client.json`, 'utf8'));

describe('repository client configs', () => {
  const slugs = readdirSync(clientsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith('_'))
    .map((entry) => entry.name);

  it('has at least one client', () => {
    expect(slugs.length).toBeGreaterThan(0);
  });

  it.each(slugs)('%s is valid and its folder matches its slug', (slug) => {
    const config = parseClientConfig(load(slug));
    expect(config.slug).toBe(slug);
  });

  it('template is valid apart from its placeholder slug', () => {
    expect(safeParseClientConfig(load('_template')).success).toBe(true);
  });
});

describe('presets', () => {
  it('fills missing sections from the business type preset', () => {
    const config = parseClientConfig(load('sharma_kirana'));
    expect(config.catalog.variantStyle).toBe('units');
    expect(config.features.deliverySlots).toBe(true);
    expect(config.delivery.feePaise).toBe(PRESETS.grocery.delivery.feePaise);
    // overridden value from client.json wins
    expect(config.delivery.pincodes).toEqual(['364001', '364002', '364003']);
  });

  it('client overrides individual flags', () => {
    const config = parseClientConfig(load('style_hub'));
    expect(config.catalog.variantAxes).toEqual(['size', 'color']);
    expect(config.features.deliverySlots).toBe(false);
    expect(config.features.returns).toBe(true);
  });

  it('every preset produces a valid config', () => {
    const base = load('sharma_kirana');
    for (const businessType of Object.keys(PRESETS)) {
      const raw = deepMerge(base, { shop: { businessType } });
      const result = safeParseClientConfig(raw);
      expect(result.success, `${businessType}: ${JSON.stringify(result.error?.issues)}`).toBe(true);
    }
  });
});

describe('validation', () => {
  const base = load('sharma_kirana');
  const issues = (override: unknown) => {
    const result = safeParseClientConfig(deepMerge(base, override));
    expect(result.success).toBe(false);
    return result.error!.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`).join('\n');
  };

  it('rejects bad slugs', () => {
    expect(issues({ slug: 'Sharma-Kirana' })).toMatch(/^slug/m);
  });

  it('rejects bad colours', () => {
    expect(issues({ branding: { colors: { primary: 'green' } } })).toMatch(/branding.colors.primary/);
  });

  it('rejects unknown keys (typos)', () => {
    expect(issues({ features: { storPickup: true } })).toMatch(/storPickup/);
  });

  it('requires a UPI id when UPI is enabled', () => {
    expect(issues({ payments: { upi: { enabled: true, vpa: 'x' } } })).toMatch(/upi/);
  });

  it('requires at least one payment method', () => {
    expect(
      issues({ payments: { cod: false, upi: { enabled: false }, razorpay: { enabled: false } } }),
    ).toMatch(/payment method/);
  });

  it('requires delivery or pickup', () => {
    expect(
      issues({ delivery: { enabled: false }, features: { storePickup: false, deliverySlots: false } }),
    ).toMatch(/storePickup/);
  });

  it('slots need windows; returns policy defaults', () => {
    expect(issues({ shop: { businessType: 'clothing' }, features: { deliverySlots: true } })).toMatch(/delivery\.slots/);
    expect(issues({ delivery: { slots: { windows: [{ start: '12:00', end: '09:00' }] } } })).toMatch(/end must be after start/);
    expect(issues({ delivery: { slots: { windows: [{ start: '9am', end: '12:00' }] } } })).toMatch(/09:00/);
  });

  it('rejects slots without delivery', () => {
    expect(issues({ delivery: { enabled: false }, features: { deliverySlots: true } })).toMatch(/deliverySlots/);
  });

  it('requires default locale to be supported', () => {
    expect(issues({ locale: { default: 'hi', supported: ['en'] } })).toMatch(/locale.default/);
  });

  it('rejects money as floats', () => {
    expect(issues({ delivery: { feePaise: 20.5 } })).toMatch(/delivery.feePaise/);
  });
});

describe('toRuntimeConfig', () => {
  it('drops build-time sections', () => {
    const runtime = toRuntimeConfig(parseClientConfig(load('sharma_kirana')));
    expect(Object.keys(runtime).sort()).toEqual(['catalog', 'delivery', 'features', 'ordering', 'payments', 'returns', 'shop']);
    expect(runtime.returns).toEqual({ windowDays: 7, allowExchange: true });
    expect(runtime.delivery.slots?.windows).toHaveLength(3);
  });
});
