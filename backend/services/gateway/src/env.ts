import { commonEnv, loadEnv, readSecret } from '@qc/common';
import { z } from 'zod';

const envSchema = z.object({
  ...commonEnv,
  REDIS_URL: z.string().url(),
  JWT_PUBLIC_KEY: z.string().includes('BEGIN PUBLIC KEY', { message: 'JWT_PUBLIC_KEY(_FILE) must be a PEM public key' }),
  JWT_ISSUER: z.string().min(1).default('qc-identity'),
  TENANT_URL: z.string().url(),
  IDENTITY_URL: z.string().url(),
  CATALOG_URL: z.string().url(),
  MEDIA_URL: z.string().url(),
  ORDER_URL: z.string().url(),
  PAYMENT_URL: z.string().url(),
  DELIVERY_URL: z.string().url(),
  REPORTING_URL: z.string().url(),
  /** Dev only: proxy GET /media/* to the media service (nginx serves /media in production). */
  MEDIA_STATIC_URL: z.string().url().optional(),
  RATE_LIMIT_PER_MINUTE: z.coerce.number().int().positive().default(120),
  SHOP_CACHE_TTL_SECONDS: z.coerce.number().int().positive().default(60),
  TRUST_PROXY_HOPS: z.coerce.number().int().nonnegative().default(1),
});

export type GatewayEnv = z.infer<typeof envSchema>;

export function loadGatewayEnv(source: Record<string, string | undefined> = process.env): GatewayEnv {
  return loadEnv(envSchema, { ...source, JWT_PUBLIC_KEY: readSecret(source, 'JWT_PUBLIC_KEY') });
}
