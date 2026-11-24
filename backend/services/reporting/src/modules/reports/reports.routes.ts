import { handler, requireRole, requireShop } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import { parseRange, type ReportsService } from './reports.service.js';

const isoDay = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected a date like 2026-11-24');
const rangeQuery = { from: isoDay, to: isoDay };

/** Sales figures are for the owner only (staff run the shop floor, not the books). */
export function reportsRouter(reports: ReportsService): Router {
  const router = Router();
  router.use('/api/v1/admin/reports', requireRole('OWNER'), requireShop);

  router.get(
    '/api/v1/admin/reports/summary',
    handler({ query: z.object(rangeQuery) }, ({ query }) => reports.summary(parseRange(query.from, query.to))),
  );
  router.get(
    '/api/v1/admin/reports/daily',
    handler({ query: z.object(rangeQuery) }, ({ query }) => reports.daily(parseRange(query.from, query.to))),
  );
  router.get(
    '/api/v1/admin/reports/top-products',
    handler({ query: z.object({ ...rangeQuery, limit: z.coerce.number().int().min(1).max(50).default(10) }) }, ({ query }) =>
      reports.topProducts(parseRange(query.from, query.to), query.limit),
    ),
  );
  return router;
}
