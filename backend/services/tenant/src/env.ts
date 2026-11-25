import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

export const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
  // Privacy policy / terms: the business that runs the apps (docs/deploy.md, "Privacy policy").
  LEGAL_OPERATOR_NAME: z.string().min(2).optional(),
  LEGAL_CONTACT_EMAIL: z.email().optional(),
  LEGAL_CITY: z.string().min(2).optional(),
  LEGAL_EFFECTIVE_DATE: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

export type Env = z.infer<typeof envSchema>;

export const loadTenantEnv = (source?: Record<string, string | undefined>): Env => loadEnv(envSchema, source);
