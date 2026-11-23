import { commonEnv, loadEnv, readSecret } from '@qc/common';
import { z } from 'zod';

const envSchema = z.object({
  ...commonEnv,
  REDIS_URL: z.string().url(),
  JWT_PUBLIC_KEY: z.string().includes('BEGIN PUBLIC KEY', { message: 'JWT_PUBLIC_KEY(_FILE) must be a PEM public key' }),
  JWT_ISSUER: z.string().min(1).default('qc-identity'),
  DELIVERY_URL: z.string().url(),
});

export type RealtimeEnv = z.infer<typeof envSchema>;

export function loadRealtimeEnv(source: Record<string, string | undefined> = process.env): RealtimeEnv {
  return loadEnv(envSchema, { ...source, JWT_PUBLIC_KEY: readSecret(source, 'JWT_PUBLIC_KEY') });
}
