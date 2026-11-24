import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
});

export type ReportingEnv = z.infer<typeof envSchema>;

export function loadReportingEnv(source: Record<string, string | undefined> = process.env): ReportingEnv {
  return loadEnv(envSchema, source);
}
