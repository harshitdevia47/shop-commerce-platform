import { handler, requireAdmin, requireShop, requireUser, type RawBodyRequest } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import type { PaymentsService } from './payments.service.js';

const orderParams = z.object({ orderId: z.uuid() });

export function paymentsRouter(payments: PaymentsService): Router {
  const router = Router();

  // Customer (own orders) or admin.
  router.get('/api/v1/payments/orders/:orderId', requireUser, requireShop, handler({ params: orderParams }, ({ params }) => payments.get(params.orderId)));
  router.post(
    '/api/v1/payments/orders/:orderId/utr',
    requireUser,
    requireShop,
    handler(
      { params: orderParams, body: z.object({ utr: z.string().regex(/^\d{12}$/, 'UTR is the 12-digit UPI reference number') }).strict() },
      ({ params, body }) => payments.submitUtr(params.orderId, body.utr),
    ),
  );

  router.post(
    '/api/v1/payments/orders/:orderId/razorpay',
    requireUser,
    requireShop,
    handler(
      {
        params: orderParams,
        body: z
          .object({
            razorpayOrderId: z.string().min(1).max(64),
            razorpayPaymentId: z.string().min(1).max(64),
            razorpaySignature: z.string().regex(/^[a-f0-9]{64}$/),
          })
          .strict(),
      },
      ({ params, body }) => payments.confirmOnline(params.orderId, body),
    ),
  );

  // Razorpay webhook. The gateway takes the shop from the URL (/api/v1/webhooks/razorpay/<slug>).
  router.post(
    '/api/v1/webhooks/razorpay/:slug',
    requireShop,
    handler({}, async (_input, req) =>
      payments.razorpayWebhook((req as RawBodyRequest).rawBody, req.header('x-razorpay-signature') ?? undefined),
    ),
  );

  router.get(
    '/api/v1/admin/payments',
    requireAdmin,
    requireShop,
    handler({ query: z.object({ status: z.enum(['PENDING', 'SUBMITTED', 'PAID', 'VOID']).optional() }) }, ({ query }) =>
      payments.listForAdmin(query.status),
    ),
  );
  router.post(
    '/api/v1/admin/payments/orders/:orderId/mark-paid',
    requireAdmin,
    requireShop,
    handler({ params: orderParams }, ({ params }) => payments.markPaid(params.orderId)),
  );

  // Internal (order saga).
  router.post(
    '/internal/payments',
    requireShop,
    handler(
      {
        body: z
          .object({
            orderId: z.uuid(),
            orderNumber: z.number().int().positive(),
            customerId: z.uuid(),
            method: z.enum(['COD', 'UPI', 'RAZORPAY']),
            amountPaise: z.number().int().positive(),
          })
          .strict(),
      },
      ({ body }) => payments.create(body),
      201,
    ),
  );
  router.post(
    '/internal/payments/void',
    requireShop,
    handler({ body: z.object({ orderId: z.uuid() }).strict() }, ({ body }) => payments.void(body.orderId)),
  );

  return router;
}
