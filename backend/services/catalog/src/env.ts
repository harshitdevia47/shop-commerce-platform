import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
  TENANT_URL: z.string().url(),
  MEDIA_URL: z.string().url(),
  SHOP_CONFIG_CACHE_SECONDS: z.coerce.number().int().nonnegative().default(60),
});

export type CatalogEnv = z.infer<typeof envSchema>;

export function loadCatalogEnv(source: Record<string, string | undefined> = process.env): CatalogEnv {
  return loadEnv(envSchema, source);
}
