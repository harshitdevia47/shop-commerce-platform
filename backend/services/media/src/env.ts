import { commonEnv, loadEnv } from '@qc/common';
import { z } from 'zod';

const booleanString = z
  .enum(['true', 'false', '1', '0'])
  .default('false')
  .transform((v) => v === 'true' || v === '1');

const envSchema = z.object({
  ...commonEnv,
  DATABASE_URL: z.string().url(),
  /** Root folder for files: <MEDIA_ROOT>/public/<shopId>/... and <MEDIA_ROOT>/private/<shopId>/... */
  MEDIA_ROOT: z.string().min(1),
  /** URL prefix of public files as seen by clients (nginx serves MEDIA_ROOT/public there). */
  MEDIA_PUBLIC_PATH: z.string().startsWith('/').default('/media'),
  /** Dev only: serve public files from this service too. */
  MEDIA_SERVE_STATIC: booleanString,
  MAX_UPLOAD_BYTES: z.coerce.number().int().positive().default(8 * 1024 * 1024),
});

export type MediaEnv = z.infer<typeof envSchema>;

export function loadMediaEnv(source: Record<string, string | undefined> = process.env): MediaEnv {
  return loadEnv(envSchema, source);
}
