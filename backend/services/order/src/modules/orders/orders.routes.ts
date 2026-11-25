import { handler, requireAdmin, requireShop, requireUser } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import type { OrdersService } from './orders.service.js';

const items = z
  .array(z.object({ variantId: z.uuid(), qty: z.number().int().min(1).max(99) }).strict())
  .max(100);
const quoteItems = items.min(1);
const fulfillment = z.enum(['DELIVERY', 'PICKUP']);
const idParams = z.object({ id: z.uuid() });
const STATUSES = [
  'PLACED',
  'CONFIRMED',
  'PACKED',
  'OUT_FOR_DELIVERY',
  'READY_FOR_PICKUP',
  'DELIVERED',
  'PICKED_UP',
  'CANCELLED',
  'REJECTED',
] as const;
const page = {
  cursor: z.uuid().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
};

export function ordersRouter(orders: OrdersService): Router {
  const router = Router();

  // Cart pricing: public (guests see totals before logging in).
  router.post(
    '/api/v1/orders/quote',
    requireShop,
    handler({ body: z.object({ items: quoteItems, fulfillment: fulfillment.default('DELIVERY') }).strict() }, ({ body }) =>
      orders.quote(body.items, body.fulfillment),
    ),
  );

  // Delivery windows (public, like the quote).
  router.get('/api/v1/orders/slots', requireShop, handler({}, () => orders.slots()));

  const mine = Router();
  mine.use(requireUser, requireShop);
  mine.post(
    '/',
    handler(
      {
        body: z
          .object({
            items,
            fulfillment,
            addressId: z.uuid().optional(),
            paymentMethod: z.enum(['COD', 'UPI', 'RAZORPAY']),
            note: z.string().trim().min(1).max(500).optional(),
            idempotencyKey: z.uuid(),
            expectedTotalPaise: z.number().int().nonnegative().optional(),
            slotStart: z.iso.datetime({ offset: true }).optional(),
            attachmentIds: z.array(z.uuid()).max(5).optional(),
          })
          .strict(),
      },
      ({ body }) => orders.place(body),
      201,
    ),
  );
  mine.get('/', handler({ query: z.object(page) }, ({ query }) => orders.listMine(query)));
  mine.get('/:id', handler({ params: idParams }, ({ params }) => orders.getMine(params.id)));
  mine.post(
    '/:id/cancel',
    handler(
      { params: idParams, body: z.object({ reason: z.string().trim().min(1).max(200).optional() }).strict() },
      ({ params, body }) => orders.cancelMine(params.id, body.reason),
    ),
  );
  router.use('/api/v1/orders', mine);

  const admin = Router();
  admin.use(requireAdmin, requireShop);
  admin.get(
    '/',
    handler(
      { query: z.object({ ...page, status: z.enum(STATUSES).optional(), group: z.enum(['new', 'active', 'done']).optional() }) },
      ({ query }) => orders.listForShop(query),
    ),
  );
  admin.get('/:id', handler({ params: idParams }, ({ params }) => orders.getForShop(params.id)));
  admin.post(
    '/:id/status',
    handler(
      {
        params: idParams,
        body: z
          .object({
            status: z.enum(STATUSES),
            reason: z.string().trim().min(1).max(200).optional(),
            /** List orders: the amount the shop charges (paise), when accepting. */
            amountPaise: z.number().int().positive().max(10_000_000).optional(),
          })
          .strict(),
      },
      ({ params, body }) => orders.setStatus(params.id, body.status, body.reason, body.amountPaise),
    ),
  );
  router.use('/api/v1/admin/orders', admin);

  // Internal only (delivery service): order snapshot for the rider, and rider status changes.
  // The delivery service has checked the assignment (and the OTP) and calls in the rider's context.
  router.get('/internal/orders/:id', requireShop, handler({ params: idParams }, ({ params }) => orders.getForShop(params.id)));
  router.post(
    '/internal/orders/:id/status',
    requireShop,
    handler({ params: idParams, body: z.object({ status: z.enum(['OUT_FOR_DELIVERY', 'DELIVERED']) }).strict() }, ({ params, body }) =>
      orders.setStatus(params.id, body.status),
    ),
  );

  // Internal only (identity, before deleting an account): orders of this customer still in progress.
  router.get(
    '/internal/orders/customers/:userId/open-count',
    requireShop,
    handler({ params: z.object({ userId: z.uuid() }) }, async ({ params }) => ({ count: await orders.openCountFor(params.userId) })),
  );

  // Internal only (catalog/payment sweepers). The gateway never routes /internal.
  router.post(
    '/internal/orders/existing',
    requireShop,
    handler({ body: z.object({ ids: z.array(z.uuid()).min(1).max(200) }).strict() }, async ({ body }) => ({
      ids: await orders.existing(body.ids),
    })),
  );

  return router;
}
