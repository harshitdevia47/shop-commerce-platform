import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  TENANT_URL: z.string().url(),
  ORDER_URL: z.string().url(),
  /** Folder with one Razorpay credentials file per shop (<slug>.json). Unset = no online payments. */
  RAZORPAY_ACCOUNTS_DIR: z.string().optional(),
  SHOP_CONFIG_CACHE_SECONDS: z.coerce.number().int().nonnegative().default(60),
});

export type PaymentEnv = z.infer<typeof envSchema>;

export function loadPaymentEnv(source: Record<string, string | undefined> = process.env): PaymentEnv {
  return loadEnv(envSchema, source);
}
