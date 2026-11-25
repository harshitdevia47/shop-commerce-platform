import { commonEnv, loadEnv, readSecret } from '@qc/common';
import { z } from 'zod';

const emailList = z
  .string()
  .transform((v) => v.split(',').map((e) => e.trim().toLowerCase()).filter(Boolean))
  .pipe(z.array(z.email()).min(1, 'ADMIN_EMAILS needs at least one email'));

const envSchema = z
  .object({
    ...commonEnv,
    DATABASE_URL: z.string().url(),
    REDIS_URL: z.string().url(),
    /** Who may log in (comma separated). */
    ADMIN_EMAILS: emailList,
    LOGIN_CODE_SECRET: z.string().min(32, 'LOGIN_CODE_SECRET must be at least 32 characters'),
    MAIL_PROVIDER: z.enum(['console', 'gmail']).default('console'),
    MAIL_USER: z.email().optional(),
    MAIL_APP_PASSWORD: z.string().optional(),
    /** Overdue alerts to the Shop Admin app: fcm (Firebase), console (log, dev) or none (email only). */
    PUSH_PROVIDER: z.enum(['none', 'console', 'fcm']).default('none'),
    FCM_SERVICE_ACCOUNT: z.string().optional(),
    /** Fallback inbox for alerts when no phone is registered (default: the first admin email). */
    MAIL_TO: z.email().optional(),
    TENANT_URL: z.string().url(),
    IDENTITY_URL: z.string().url(),
    CATALOG_URL: z.string().url(),
    REPORTING_URL: z.string().url(),
    /** UPI ID shops pay the subscription to. */
    PLATFORM_UPI_ID: z.string().trim().min(3).optional(),
    /** Prefilled monthly fee (₹) for new subscriptions. */
    PLATFORM_DEFAULT_FEE_RUPEES: z.coerce.number().int().positive().max(100_000).optional(),
    /** sha256 (hex) of the token `npm run new-shop` sends; unset = the new-shop API is off. */
    PLATFORM_API_TOKEN_HASH: z.string().regex(/^[0-9a-f]{64}$/).optional(),
  })
  .superRefine((env, ctx) => {
    if (env.MAIL_PROVIDER === 'gmail' && (!env.MAIL_USER || !env.MAIL_APP_PASSWORD)) {
      ctx.addIssue({ code: 'custom', path: ['MAIL_USER'], message: 'MAIL_PROVIDER=gmail needs MAIL_USER and MAIL_APP_PASSWORD(_FILE)' });
    }
    if (env.PUSH_PROVIDER === 'fcm' && !env.FCM_SERVICE_ACCOUNT) {
      ctx.addIssue({ code: 'custom', path: ['FCM_SERVICE_ACCOUNT'], message: 'PUSH_PROVIDER=fcm needs FCM_SERVICE_ACCOUNT(_FILE)' });
    }
    if (env.NODE_ENV === 'production' && env.MAIL_PROVIDER === 'console') {
      ctx.addIssue({ code: 'custom', path: ['MAIL_PROVIDER'], message: 'console mail is not allowed in production' });
    }
  });

export type PlatformEnv = z.infer<typeof envSchema>;

export function loadPlatformEnv(source: Record<string, string | undefined> = process.env): PlatformEnv {
  return loadEnv(envSchema, {
    ...source,
    MAIL_APP_PASSWORD: readSecret(source, 'MAIL_APP_PASSWORD'),
    FCM_SERVICE_ACCOUNT: readSecret(source, 'FCM_SERVICE_ACCOUNT'),
  });
}
