import { handler, requireShop } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import type { StockService } from './stock.service.js';

const items = z
  .array(z.object({ variantId: z.uuid(), qty: z.number().int().min(1).max(1000) }).strict())
  .min(1)
  .max(100);

/** Internal only (order service). The gateway never routes /internal. */
export function stockRouter(stock: StockService): Router {
  const router = Router();
  router.use('/internal/catalog', requireShop);

  router.post(
    '/internal/catalog/variants/lookup',
    handler({ body: z.object({ ids: z.array(z.uuid()).min(1).max(100) }).strict() }, ({ body }) => stock.lookup(body.ids)),
  );
  router.post(
    '/internal/catalog/stock/reserve',
    handler({ body: z.object({ orderId: z.uuid(), items }).strict() }, async ({ body }) => {
      await stock.reserve(body.orderId, body.items);
      return { reserved: true };
    }),
  );
  router.post(
    '/internal/catalog/stock/release',
    handler({ body: z.object({ orderId: z.uuid() }).strict() }, async ({ body }) => {
      await stock.release(body.orderId);
      return { released: true };
    }),
  );
  return router;
}
