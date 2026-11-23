import { commonEnv, loadEnv, readSecret } from '@qc/common';
import { z } from 'zod';

const envSchema = z
  .object({
    ...commonEnv,
    DATABASE_URL: z.string().url(),
    REDIS_URL: z.string().url(),
    TENANT_URL: z.string().url(),
    IDENTITY_URL: z.string().url(),
    SHOP_CONFIG_CACHE_SECONDS: z.coerce.number().int().nonnegative().default(60),
    /** `console` logs pushes (development / pilots without Firebase); `fcm` sends them. */
    PUSH_PROVIDER: z.enum(['console', 'fcm']).default('console'),
    /** Firebase service account JSON (inline, or a path via FCM_SERVICE_ACCOUNT_FILE). Needed for `fcm`. */
    FCM_SERVICE_ACCOUNT: z.string().optional(),
  })
  .refine((env) => env.PUSH_PROVIDER !== 'fcm' || env.FCM_SERVICE_ACCOUNT, {
    message: 'PUSH_PROVIDER=fcm needs FCM_SERVICE_ACCOUNT or FCM_SERVICE_ACCOUNT_FILE',
    path: ['FCM_SERVICE_ACCOUNT'],
  });

export type NotificationEnv = z.infer<typeof envSchema>;

export function loadNotificationEnv(source: Record<string, string | undefined> = process.env): NotificationEnv {
  return loadEnv(envSchema, { ...source, FCM_SERVICE_ACCOUNT: readSecret(source, 'FCM_SERVICE_ACCOUNT') });
}
