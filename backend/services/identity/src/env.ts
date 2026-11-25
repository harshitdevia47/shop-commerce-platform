import { commonEnv, loadEnv, readSecret } from '@qc/common';
import { z } from 'zod';

const booleanString = z
  .enum(['true', 'false', '1', '0'])
  .default('false')
  .transform((v) => v === 'true' || v === '1');

export const SMS_PROVIDERS = ['console', 'msg91', 'whatsapp'] as const;

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
    MSG91_AUTH_KEY: z.string().optional(),
    MSG91_OTP_TEMPLATE_ID: z.string().optional(),
    MSG91_OTP_VARIABLE: z.string().regex(/^[A-Za-z0-9_]+$/).default('otp'),
    WHATSAPP_PHONE_NUMBER_ID: z.string().regex(/^\d+$/).optional(),
    WHATSAPP_ACCESS_TOKEN: z.string().optional(),
    WHATSAPP_OTP_TEMPLATE: z.string().regex(/^[a-z0-9_]+$/).default('login_code'),
    WHATSAPP_API_VERSION: z.string().regex(/^v\d+\.\d+$/).default('v21.0'),
    /** Dev only: include the OTP in the API response so emulators can log in without SMS. */
    OTP_DEV_ECHO: booleanString,
    /** Order service (open orders block account deletion). */
    ORDER_URL: z.string().url(),
    /** Used by scripts/users.ts to resolve shop slugs. */
    TENANT_URL: z.string().url().optional(),
  })
  .superRefine((env, ctx) => {
    if (env.SMS_PROVIDER === 'msg91' && (!env.MSG91_AUTH_KEY || !env.MSG91_OTP_TEMPLATE_ID)) {
      ctx.addIssue({ code: 'custom', path: ['MSG91_AUTH_KEY'], message: 'SMS_PROVIDER=msg91 needs MSG91_AUTH_KEY(_FILE) and MSG91_OTP_TEMPLATE_ID' });
    }
    if (env.SMS_PROVIDER === 'whatsapp' && (!env.WHATSAPP_PHONE_NUMBER_ID || !env.WHATSAPP_ACCESS_TOKEN)) {
      ctx.addIssue({
        code: 'custom',
        path: ['WHATSAPP_ACCESS_TOKEN'],
        message: 'SMS_PROVIDER=whatsapp needs WHATSAPP_PHONE_NUMBER_ID and WHATSAPP_ACCESS_TOKEN(_FILE)',
      });
    }
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
  return loadEnv(envSchema, {
    ...source,
    JWT_PRIVATE_KEY: readSecret(source, 'JWT_PRIVATE_KEY'),
    MSG91_AUTH_KEY: readSecret(source, 'MSG91_AUTH_KEY'),
    WHATSAPP_ACCESS_TOKEN: readSecret(source, 'WHATSAPP_ACCESS_TOKEN'),
  });
}
