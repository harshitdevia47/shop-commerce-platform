import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
  TENANT_URL: z.string().url(),
  SHOP_CONFIG_CACHE_SECONDS: z.coerce.number().int().nonnegative().default(60),
});

export type PaymentEnv = z.infer<typeof envSchema>;

export function loadPaymentEnv(source: Record<string, string | undefined> = process.env): PaymentEnv {
  return loadEnv(envSchema, source);
}
