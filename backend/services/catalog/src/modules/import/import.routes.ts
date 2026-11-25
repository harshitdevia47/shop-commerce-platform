import { handler, requireAdmin, requireShop } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import { MAX_IMPORT_ROWS, type ImportService } from './import.service.js';

const body = z
  .object({
    /** Spreadsheet rows, header first (the app reads Excel/CSV files into rows). */
    rows: z.array(z.array(z.string().max(4000)).max(60)).min(1).max(MAX_IMPORT_ROWS + 1),
    /** true = check and report only, nothing saved. */
    dryRun: z.boolean().default(true),
  })
  .strict();

export function importRouter(service: ImportService): Router {
  const router = Router();
  router.get('/api/v1/admin/catalog/import/template', requireAdmin, requireShop, handler({}, () => service.template()));
  router.post(
    '/api/v1/admin/catalog/import',
    requireAdmin,
    requireShop,
    handler({ body }, ({ body }) => service.run(body.rows, { dryRun: body.dryRun })),
  );
  return router;
}
