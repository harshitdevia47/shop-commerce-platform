import type { BusinessType, CatalogConfig, DeliveryConfig, Features } from './schema.js';

/**
 * Defaults per business type. A client's client.json is deep-merged on top of
 * its preset, so a client file only needs the values that differ.
 */
export interface Preset {
  features: Features;
  delivery: DeliveryConfig;
  catalog: CatalogConfig;
}

const baseFeatures: Features = {
  deliverySlots: false,
  storePickup: true,
  returns: false,
  prescriptionUpload: false,
  orderNotes: true,
  handwrittenListUpload: false,
};

const baseDelivery: DeliveryConfig = {
  enabled: true,
  radiusKm: 5,
  pincodes: [],
  minOrderPaise: 0,
  feePaise: 0,
  freeAbovePaise: null,
  etaMinutes: 60,
};

export const PRESETS: Record<BusinessType, Preset> = {
  grocery: {
    features: { ...baseFeatures, deliverySlots: true, handwrittenListUpload: true },
    delivery: { ...baseDelivery, minOrderPaise: 10_000, feePaise: 2_000, freeAbovePaise: 50_000, etaMinutes: 45 },
    catalog: {
      variantStyle: 'units',
      variantAxes: [],
      customFields: [{ key: 'brand', type: 'text', label: { en: 'Brand', gu: 'બ્રાન્ડ', hi: 'ब्रांड' }, required: false }],
    },
  },
  clothing: {
    features: { ...baseFeatures, returns: true },
    delivery: { ...baseDelivery, radiusKm: 10, etaMinutes: 24 * 60 },
    catalog: {
      variantStyle: 'options',
      variantAxes: ['size', 'color'],
      customFields: [
        { key: 'fabric', type: 'text', label: { en: 'Fabric', gu: 'કાપડ', hi: 'कपड़ा' }, required: false },
        {
          key: 'gender',
          type: 'select',
          label: { en: 'For', gu: 'કોના માટે', hi: 'किसके लिए' },
          required: false,
          options: ['men', 'women', 'kids', 'unisex'],
        },
      ],
    },
  },
  bakery: {
    features: { ...baseFeatures, deliverySlots: true },
    delivery: { ...baseDelivery, radiusKm: 4, etaMinutes: 60 },
    catalog: {
      variantStyle: 'options',
      variantAxes: ['size', 'flavour'],
      customFields: [
        { key: 'eggless', type: 'boolean', label: { en: 'Eggless', gu: 'ઈંડા વગર', hi: 'अंडा रहित' }, required: false },
      ],
    },
  },
  electronics: {
    features: { ...baseFeatures, returns: true, orderNotes: true },
    delivery: { ...baseDelivery, radiusKm: 15, etaMinutes: 24 * 60 },
    catalog: {
      variantStyle: 'options',
      variantAxes: ['color', 'storage'],
      customFields: [
        { key: 'brand', type: 'text', label: { en: 'Brand', gu: 'બ્રાન્ડ', hi: 'ब्रांड' }, required: false },
        { key: 'warrantyMonths', type: 'number', label: { en: 'Warranty (months)' }, required: false },
      ],
    },
  },
  pharmacy: {
    features: { ...baseFeatures, prescriptionUpload: true, handwrittenListUpload: true },
    delivery: { ...baseDelivery, radiusKm: 5, etaMinutes: 45 },
    catalog: {
      variantStyle: 'units',
      variantAxes: [],
      customFields: [
        {
          key: 'prescriptionRequired',
          type: 'boolean',
          label: { en: 'Prescription required', gu: 'પ્રિસ્ક્રિપ્શન જરૂરી', hi: 'पर्चा ज़रूरी' },
          required: false,
        },
      ],
    },
  },
  general: {
    features: baseFeatures,
    delivery: baseDelivery,
    catalog: { variantStyle: 'single', variantAxes: [], customFields: [] },
  },
};
