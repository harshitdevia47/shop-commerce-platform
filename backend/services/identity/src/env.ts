import { commonEnv, loadEnv, readSecret } from '@qc/common';
import { z } from 'zod';

const booleanString = z
  .enum(['true', 'false', '1', '0'])
  .default('false')
  .transform((v) => v === 'true' || v === '1');

export const SMS_PROVIDERS = ['console'] as const;

const envSchema = z
  .object({
    ...commonEnv,
    DATABASE_URL: z.string().url(),
    REDIS_URL: z.string().url(),
    JWT_PRIVATE_KEY: z.string().includes('PRIVATE KEY', { message: 'JWT_PRIVATE_KEY(_FILE) must be a PEM private key' }),
    JWT_ISSUER: z.string().min(1).default('qc-identity'),
    ACCESS_TOKEN_TTL_SECONDS: z.coerce.number().int().min(60).max(3600).default(900),
    REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).max(180).default(30),
    /** Pepper for OTP hashes. */
    OTP_SECRET: z.string().min(32, 'OTP_SECRET must be at least 32 characters'),
    SMS_PROVIDER: z.enum(SMS_PROVIDERS).default('console'),
    /** Dev only: include the OTP in the API response so emulators can log in without SMS. */
    OTP_DEV_ECHO: booleanString,
    /** Used by scripts/users.ts to resolve shop slugs. */
    TENANT_URL: z.string().url().optional(),
  })
  .superRefine((env, ctx) => {
    if (env.NODE_ENV !== 'production') return;
    if (env.SMS_PROVIDER === 'console') {
      ctx.addIssue({ code: 'custom', path: ['SMS_PROVIDER'], message: 'console SMS provider is not allowed in production' });
    }
    if (env.OTP_DEV_ECHO) {
      ctx.addIssue({ code: 'custom', path: ['OTP_DEV_ECHO'], message: 'OTP_DEV_ECHO must be false in production' });
    }
  });

export type IdentityEnv = z.infer<typeof envSchema>;

export function loadIdentityEnv(source: Record<string, string | undefined> = process.env): IdentityEnv {
  return loadEnv(envSchema, { ...source, JWT_PRIVATE_KEY: readSecret(source, 'JWT_PRIVATE_KEY') });
}
