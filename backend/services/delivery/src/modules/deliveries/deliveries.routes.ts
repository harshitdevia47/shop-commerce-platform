import { handler, requireAdmin, requireRole, requireShop, requireUser } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import type { DeliveriesService } from './deliveries.service.js';

const id = z.object({ id: z.uuid() });
const orderParams = z.object({ orderId: z.uuid() });

export function deliveriesRouter(deliveries: DeliveriesService): Router {
  const router = Router();

  const admin = Router();
  admin.use(requireAdmin, requireShop);
  admin.get('/riders', handler({}, () => deliveries.riders()));
  admin.post(
    '/deliveries',
    handler({ body: z.object({ orderId: z.uuid(), riderId: z.uuid() }).strict() }, ({ body }) =>
      deliveries.assign(body.orderId, body.riderId),
    ),
  );
  admin.get('/deliveries/orders/:orderId', handler({ params: orderParams }, ({ params }) => deliveries.forOrderAsAdmin(params.orderId)));
  router.use('/api/v1/admin', admin);

  const rider = Router();
  rider.use(requireRole('RIDER'), requireShop);
  rider.get(
    '/',
    handler({ query: z.object({ group: z.enum(['active', 'done']).default('active') }) }, ({ query }) => deliveries.listMine(query.group)),
  );
  rider.get('/:id', handler({ params: id }, ({ params }) => deliveries.getMine(params.id)));
  rider.post('/:id/pickup', handler({ params: id }, ({ params }) => deliveries.pickUp(params.id)));
  rider.post(
    '/:id/deliver',
    handler({ params: id, body: z.object({ otp: z.string().regex(/^\d{4}$/, 'Code must be 4 digits') }).strict() }, ({ params, body }) =>
      deliveries.deliver(params.id, body.otp),
    ),
  );
  router.use('/api/v1/rider/deliveries', rider);

  router.get(
    '/api/v1/deliveries/orders/:orderId',
    requireUser,
    requireShop,
    handler({ params: orderParams }, ({ params }) => deliveries.forOrderAsCustomer(params.orderId)),
  );

  // Internal only (realtime service forwards rider location pings in the rider's context).
  router.post(
    '/internal/deliveries/location',
    requireRole('RIDER'),
    requireShop,
    handler(
      {
        body: z
          .object({
            lat: z.number().min(-90).max(90),
            lng: z.number().min(-180).max(180),
            accuracy: z.number().nonnegative().max(10_000).nullable().default(null),
          })
          .strict(),
      },
      ({ body }) => deliveries.reportLocation(body),
    ),
  );

  return router;
}
