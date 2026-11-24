import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  TENANT_URL: z.string().url(),
  IDENTITY_URL: z.string().url(),
  CATALOG_URL: z.string().url(),
  PAYMENT_URL: z.string().url(),
  MEDIA_URL: z.string().url(),
  SHOP_CONFIG_CACHE_SECONDS: z.coerce.number().int().nonnegative().default(60),
});

export type OrderEnv = z.infer<typeof envSchema>;

export function loadOrderEnv(source: Record<string, string | undefined> = process.env): OrderEnv {
  return loadEnv(envSchema, source);
}
