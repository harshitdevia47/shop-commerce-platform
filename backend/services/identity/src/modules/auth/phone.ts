import { z } from 'zod';

const INDIAN_MOBILE = /^[6-9]\d{9}$/;

/**
 * Normalises common Indian mobile formats to E.164:
 * "98765 43210", "09876543210", "919876543210", "+91-98765-43210" -> "+919876543210".
 * Returns null for anything that is not a valid Indian mobile number.
 */
export function normalizeIndianMobile(input: string): string | null {
  const digits = input.trim().replace(/[\s\-().]/g, '');
  const local = digits.startsWith('+91')
    ? digits.slice(3)
    : digits.length === 12 && digits.startsWith('91')
      ? digits.slice(2)
      : digits.length === 11 && digits.startsWith('0')
        ? digits.slice(1)
        : digits;
  return INDIAN_MOBILE.test(local) ? `+91${local}` : null;
}

export const phoneSchema = z.string().transform((value, ctx) => {
  const phone = normalizeIndianMobile(value);
  if (!phone) {
    ctx.addIssue({ code: 'custom', message: 'Enter a valid 10-digit Indian mobile number' });
    return z.NEVER;
  }
  return phone;
});
