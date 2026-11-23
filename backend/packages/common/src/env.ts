import { readFileSync } from 'node:fs';
import { z } from 'zod';

/** Parses process.env (or `source`) with a Zod schema. Throws a readable error so the service fails fast. */
export function loadEnv<S extends z.ZodType>(schema: S, source: Record<string, string | undefined> = process.env): z.infer<S> {
  const result = schema.safeParse(source);
  if (!result.success) {
    throw new Error(`Invalid environment configuration:\n${z.prettifyError(result.error)}`);
  }
  return result.data;
}

/** Reads a value given inline (`NAME`) or from a file path (`NAME_FILE`), e.g. PEM keys. */
export function readSecret(source: Record<string, string | undefined>, name: string): string | undefined {
  const inline = source[name];
  if (inline) return inline.replace(/\\n/g, '\n');
  const file = source[`${name}_FILE`];
  return file ? readFileSync(file, 'utf8') : undefined;
}

export const commonEnv = {
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  PORT: z.coerce.number().int().positive().default(3000),
  INTERNAL_HMAC_SECRET: z.string().min(32, 'INTERNAL_HMAC_SECRET must be at least 32 characters'),
};
