import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

export const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
});

export type Env = z.infer<typeof envSchema>;

export const loadTenantEnv = (source?: Record<string, string | undefined>): Env => loadEnv(envSchema, source);
