import { LOCALES } from '@qc/config-schema';
import { getContext, handler, requireShop, requireUser } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import type { DevicesService } from './devices.service.js';

const token = z.string().min(20).max(4096);

export function devicesRouter(devices: DevicesService): Router {
  const router = Router();

  router.put(
    '/api/v1/me/devices',
    requireUser,
    handler(
      { body: z.object({ token, platform: z.enum(['android', 'ios']), locale: z.enum(LOCALES) }).strict() },
      async ({ body }, _req, res) => {
        await devices.register(getContext()!.userId!, body);
        res.status(204).end();
      },
    ),
  );

  // Internal only (notification service). The gateway never routes /internal.
  router.use('/internal/devices', requireShop);
  router.post(
    '/internal/devices/targets',
    handler(
      { body: z.object({ userIds: z.array(z.uuid()).max(100).optional(), admins: z.boolean().optional() }).strict() },
      ({ body }) => devices.targets(body),
    ),
  );
  router.post(
    '/internal/devices/remove',
    handler({ body: z.object({ tokens: z.array(token).min(1).max(500) }).strict() }, async ({ body }) => ({
      removed: await devices.remove(body.tokens),
    })),
  );

  return router;
}
