import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  ORDER_URL: z.string().url(),
  IDENTITY_URL: z.string().url(),
});

export type DeliveryEnv = z.infer<typeof envSchema>;

export function loadDeliveryEnv(source: Record<string, string | undefined> = process.env): DeliveryEnv {
  return loadEnv(envSchema, source);
}
