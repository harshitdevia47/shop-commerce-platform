import { getContext, handler, requireShop, requireUser } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import type { UsersService } from '../users/users.service.js';
import { toPublicUser } from '../users/users.service.js';
import { toPublicAddress, type AddressesService } from './addresses.service.js';

const text = (max: number) => z.string().trim().min(1).max(max);
const optionalText = (max: number) => text(max).nullable().optional();

const addressBody = z
  .object({
    label: z.enum(['home', 'work', 'other']).optional(),
    name: optionalText(60),
    phone: z
      .string()
      .regex(/^\+91[6-9]\d{9}$/, 'Expected an Indian mobile number like +919876543210')
      .nullable()
      .optional(),
    line1: text(200),
    line2: optionalText(200),
    landmark: optionalText(120),
    city: text(60),
    pincode: z.string().regex(/^\d{6}$/, 'Expected a 6-digit pincode'),
    lat: z.number().min(-90).max(90).nullable().optional(),
    lng: z.number().min(-180).max(180).nullable().optional(),
    isDefault: z.boolean().optional(),
  })
  .strict();

const idParams = z.object({ id: z.uuid() });
const me = () => getContext()!.userId!;

export function addressesRouter(addresses: AddressesService, users: UsersService): Router {
  const router = Router();

  const mine = Router();
  mine.use(requireUser);
  mine.get('/', handler({}, () => addresses.list(me())));
  mine.post('/', handler({ body: addressBody }, ({ body }) => addresses.create(me(), body), 201));
  mine.patch(
    '/:id',
    handler(
      { params: idParams, body: addressBody.partial().refine((b) => Object.keys(b).length > 0, { message: 'Nothing to update' }) },
      ({ params, body }) => addresses.update(me(), params.id, body),
    ),
  );
  mine.delete(
    '/:id',
    handler({ params: idParams }, async ({ params }, _req, res) => {
      await addresses.remove(me(), params.id);
      res.status(204).end();
    }),
  );
  router.use('/api/v1/me/addresses', mine);

  // Internal (order service): who is ordering and where to deliver, for the order snapshot.
  router.get(
    '/internal/users/:userId/checkout',
    requireShop,
    handler(
      { params: z.object({ userId: z.uuid() }), query: z.object({ addressId: z.uuid().optional() }) },
      async ({ params, query }) => {
        const user = await users.getById(params.userId);
        return {
          user: { ...toPublicUser(user), isBlocked: user.isBlocked },
          address: query.addressId ? toPublicAddress(await addresses.get(params.userId, query.addressId)) : null,
        };
      },
    ),
  );

  return router;
}
