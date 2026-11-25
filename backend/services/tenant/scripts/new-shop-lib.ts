/**
 * Pure helpers for `npm run new-shop`: turn plain answers into a validated client.json.
 * Kept free of I/O so they are unit-tested (test/new-shop.test.ts).
 */
import { BUSINESS_TYPES, LOCALES, SLUG_PATTERN, safeParseClientConfig, type ClientConfig } from '@qc/config-schema';
import { z } from 'zod';

export type BusinessType = (typeof BUSINESS_TYPES)[number];
export type Locale = (typeof LOCALES)[number];

/** Everything the platform team asks a new shop. Optional answers may be empty strings. */
export interface ShopAnswers {
  name: string;
  nameGu?: string;
  nameHi?: string;
  slug?: string;
  businessType: BusinessType;
  ownerName?: string;
  ownerPhone: string;
  shopPhone?: string;
  whatsapp?: string;
  address: string;
  /** "21.7645, 72.1519" or a Google Maps link containing the coordinates. */
  location: string;
  pincodes?: string;
  upiVpa?: string;
  upiName?: string;
  language?: Locale;
  primaryColor?: string;
  secondaryColor?: string;
  /** Monthly subscription to the platform (rupees) and the day of the month it is due (1–28). */
  feeRupees?: string;
  dueDay?: string;
}

/** "Sharma Kirana Store" → "sharma_kirana_store" (valid slug, folder name and X-Shop-Key). */
export function slugify(name: string): string {
  const slug = name
    .normalize('NFKD')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .replace(/^[0-9_]+/, '')
    .slice(0, 40)
    .replace(/_+$/, '');
  return slug || 'shop';
}

/** 98765 43210 / +91 98765-43210 / 098765 43210 → +919876543210; null when not an Indian mobile. */
export function normalizePhone(input: string): string | null {
  const digits = input.replace(/\D/g, '').replace(/^(91|0)(?=\d{10}$)/, '');
  return /^[6-9]\d{9}$/.test(digits) ? `+91${digits}` : null;
}

/**
 * Reads coordinates from "lat, lng" or a Google Maps link ("@21.76,72.15,17z", "?q=21.76,72.15",
 * "!3d21.76!4d72.15"). Short links (maps.app.goo.gl) do not contain them: open the link, then copy
 * the coordinates from the address bar or by long-pressing the pin.
 */
export function parseLocation(input: string): { lat: number; lng: number } | null {
  const text = decodeURIComponent(input.trim());
  const patterns = [/!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/, /@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/, /(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)/];
  for (const pattern of patterns) {
    const match = pattern.exec(text);
    if (!match) continue;
    const lat = Number(match[1]);
    const lng = Number(match[2]);
    if (Math.abs(lat) <= 90 && Math.abs(lng) <= 180) return { lat: round(lat), lng: round(lng) };
  }
  return null;
}

const round = (n: number) => Math.round(n * 1e6) / 1e6;

export function parsePincodes(input: string | undefined): string[] | null {
  const list = (input ?? '').split(/[\s,;]+/).filter(Boolean);
  return list.every((p) => /^\d{6}$/.test(p)) ? [...new Set(list)] : null;
}

/** Default brand colours per business type (owner/platform can change them in client.json later). */
export const DEFAULT_COLORS: Record<BusinessType, { primary: string; secondary: string }> = {
  grocery: { primary: '#1B5E20', secondary: '#FFB300' },
  clothing: { primary: '#4A148C', secondary: '#FF6F00' },
  bakery: { primary: '#6D4C41', secondary: '#F9A825' },
  electronics: { primary: '#0D47A1', secondary: '#00BFA5' },
  pharmacy: { primary: '#00695C', secondary: '#E53935' },
  general: { primary: '#1565C0', secondary: '#FFA000' },
};

/** Checks one answer the moment it is typed; returns a message to show, or null. */
export const answerChecks = {
  name: (v: string) => (v.trim().length >= 2 && v.trim().length <= 30 ? null : 'Enter 2 to 30 letters (this is also the app name)'),
  slug: (v: string) => (SLUG_PATTERN.test(v) && v.length <= 40 ? null : 'Use small letters, numbers and _ (like sharma_kirana)'),
  phone: (v: string) => (normalizePhone(v) ? null : 'Enter a 10-digit Indian mobile number'),
  optionalPhone: (v: string) => (!v.trim() || normalizePhone(v) ? null : 'Enter a 10-digit Indian mobile number, or leave empty'),
  address: (v: string) => (v.trim().length >= 5 ? null : 'Enter the full shop address'),
  location: (v: string) => (parseLocation(v) ? null : 'Paste "lat, lng" (like 21.7645, 72.1519) or a long Google Maps link'),
  pincodes: (v: string) => (parsePincodes(v) ? null : 'Pincodes have 6 digits, separated by commas'),
  upi: (v: string) => (!v.trim() || /^[A-Za-z0-9._-]{2,256}@[A-Za-z]{2,64}$/.test(v.trim()) ? null : 'Enter a UPI ID like shopname@okaxis, or leave empty'),
  color: (v: string) => (!v.trim() || /^#[0-9A-Fa-f]{6}$/.test(v.trim()) ? null : 'Enter a colour like #1B5E20, or leave empty'),
  fee: (v: string) => {
    const rupees = parseRupees(v);
    return rupees !== null && rupees > 0 && rupees <= 100_000 ? null : 'Enter the monthly fee in rupees, like 999';
  },
  dueDay: (v: string) => (/^\d{1,2}$/.test(v.trim()) && Number(v) >= 1 && Number(v) <= 28 ? null : 'Enter a due day from 1 to 28'),
};

/** "₹1,499.50" → 1499.5; null when it is not an amount. */
function parseRupees(input: string): number | null {
  const cleaned = input.replace(/[₹,\s]/g, '');
  return /^\d+(\.\d{1,2})?$/.test(cleaned) ? Number(cleaned) : null;
}

/** Monthly subscription answers → what the platform stores. Throws with a readable message. */
export function subscriptionFrom(answers: { feeRupees: string; dueDay: string }): { feePaise: number; dueDay: number } {
  const feeProblem = answerChecks.fee(answers.feeRupees);
  if (feeProblem) throw new Error(`Monthly fee: ${feeProblem}`);
  const dayProblem = answerChecks.dueDay(answers.dueDay);
  if (dayProblem) throw new Error(`Due day: ${dayProblem}`);
  return { feePaise: Math.round(parseRupees(answers.feeRupees)! * 100), dueDay: Number(answers.dueDay) };
}

export interface BuiltShop {
  config: ClientConfig;
  /** client.json as written to disk (only what differs from the business-type preset). */
  json: Record<string, unknown>;
  ownerPhone: string;
  ownerName?: string;
}

/** Answers → client.json, validated with the same schema the services use. Throws with readable issues. */
export function buildClientJson(answers: ShopAnswers): BuiltShop {
  const problems: string[] = [];
  const check = (label: string, message: string | null) => {
    if (message) problems.push(`${label}: ${message}`);
  };
  const slug = answers.slug?.trim() || slugify(answers.name);
  check('Shop name', answerChecks.name(answers.name));
  check('Short id', answerChecks.slug(slug));
  check('Owner mobile', answerChecks.phone(answers.ownerPhone));
  check('Shop phone', answerChecks.optionalPhone(answers.shopPhone ?? ''));
  check('WhatsApp', answerChecks.optionalPhone(answers.whatsapp ?? ''));
  check('Address', answerChecks.address(answers.address));
  check('Location', answerChecks.location(answers.location));
  check('Pincodes', answerChecks.pincodes(answers.pincodes ?? ''));
  check('UPI ID', answerChecks.upi(answers.upiVpa ?? ''));
  check('Primary colour', answerChecks.color(answers.primaryColor ?? ''));
  check('Second colour', answerChecks.color(answers.secondaryColor ?? ''));
  if (answers.upiVpa?.trim() && !(answers.upiName?.trim() || answers.name.trim())) check('UPI name', 'Required with a UPI ID');
  if (problems.length > 0) throw new Error(problems.join('\n'));

  const ownerPhone = normalizePhone(answers.ownerPhone)!;
  const shopPhone = (answers.shopPhone?.trim() && normalizePhone(answers.shopPhone)) || ownerPhone;
  const whatsapp = answers.whatsapp?.trim() ? normalizePhone(answers.whatsapp)! : shopPhone;
  const { lat, lng } = parseLocation(answers.location)!;
  const pincodes = parsePincodes(answers.pincodes)!;
  const colors = DEFAULT_COLORS[answers.businessType];
  const name = answers.name.trim();
  const nameI18n = {
    ...(answers.nameGu?.trim() ? { gu: answers.nameGu.trim() } : {}),
    ...(answers.nameHi?.trim() ? { hi: answers.nameHi.trim() } : {}),
  };
  const upi = answers.upiVpa?.trim();

  const json: Record<string, unknown> = {
    slug,
    build: {
      appName: name,
      // Package ids cannot change after the first Play upload: derived once from the slug.
      androidPackage: `in.qcommerce.${slug.replace(/_/g, '')}`,
      version: '1.0.0+1',
    },
    branding: {
      logo: 'logo.png',
      icon: 'icon.png',
      colors: {
        primary: answers.primaryColor?.trim() || colors.primary,
        secondary: answers.secondaryColor?.trim() || colors.secondary,
      },
    },
    locale: { default: answers.language ?? 'gu', supported: ['en', 'gu', 'hi'] },
    shop: {
      name,
      ...(Object.keys(nameI18n).length ? { nameI18n } : {}),
      businessType: answers.businessType,
      contact: { phone: shopPhone, whatsapp, address: answers.address.trim(), lat, lng },
    },
    ...(pincodes.length ? { delivery: { pincodes } } : {}),
    payments: {
      cod: true,
      upi: upi ? { enabled: true, vpa: upi, payeeName: (answers.upiName?.trim() || name).slice(0, 50) } : { enabled: false },
      razorpay: { enabled: false },
    },
  };

  const parsed = safeParseClientConfig(json);
  if (!parsed.success) throw new Error(z.prettifyError(parsed.error));
  return { config: parsed.data, json, ownerPhone, ...(answers.ownerName?.trim() ? { ownerName: answers.ownerName.trim() } : {}) };
}
