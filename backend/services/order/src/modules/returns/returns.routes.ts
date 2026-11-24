import { handler, requireAdmin, requireShop, requireUser } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import type { ReturnsService } from './returns.service.js';

const STATUSES = ['REQUESTED', 'APPROVED', 'REJECTED', 'COMPLETED'] as const;

export function returnsRouter(returns: ReturnsService): Router {
  const router = Router();

  router.post(
    '/api/v1/orders/:id/return',
    requireUser,
    requireShop,
    handler(
      {
        params: z.object({ id: z.uuid() }),
        body: z
          .object({
            type: z.enum(['RETURN', 'EXCHANGE']),
            reason: z.string().trim().min(3).max(500),
            items: z.array(z.object({ variantId: z.uuid(), qty: z.number().int().min(1).max(99) }).strict()).max(100),
            photoIds: z.array(z.uuid()).max(5).optional(),
          })
          .strict(),
      },
      ({ params, body }) => returns.request(params.id, body),
      201,
    ),
  );

  const admin = Router();
  admin.use(requireAdmin, requireShop);
  admin.get('/', handler({ query: z.object({ status: z.enum(STATUSES).optional() }) }, ({ query }) => returns.listForShop(query.status)));
  admin.post(
    '/:id/status',
    handler(
      {
        params: z.object({ id: z.uuid() }),
        body: z.object({ status: z.enum(['APPROVED', 'REJECTED', 'COMPLETED']), note: z.string().trim().min(1).max(300).optional() }).strict(),
      },
      ({ params, body }) => returns.setStatus(params.id, body.status, body.note),
    ),
  );
  router.use('/api/v1/admin/returns', admin);

  return router;
}
