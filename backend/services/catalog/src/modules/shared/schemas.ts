import { i18nTextSchema } from '@qc/config-schema';
import { z } from 'zod';

export const idParams = z.object({ id: z.uuid() });

/** Optional translations of shop-entered text: { gu?, hi?, en? }. `null` clears them. */
export const i18nInput = i18nTextSchema.nullable().optional();

export const nameInput = z.string().trim().min(1).max(120);

/** Cursor pagination query. */
export const pageQuery = {
  cursor: z.uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
};
