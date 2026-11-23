import { handler, requireRole, requireShop } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import { phoneSchema } from '../auth/phone.js';
import { TEAM_ROLES, type TeamService } from './team.service.js';

export function teamRouter(team: TeamService): Router {
  const router = Router();

  // Owner only: staff cannot hire or fire.
  const owner = Router();
  owner.use(requireRole('OWNER'), requireShop);
  owner.get('/', handler({}, () => team.list()));
  owner.post(
    '/',
    handler(
      {
        body: z
          .object({ phone: phoneSchema, role: z.enum(TEAM_ROLES), name: z.string().trim().min(1).max(60).optional() })
          .strict(),
      },
      ({ body }) => team.add(body.phone, body.role, body.name),
      201,
    ),
  );
  owner.delete(
    '/:id',
    handler({ params: z.object({ id: z.uuid() }) }, async ({ params }, _req, res) => {
      await team.remove(params.id);
      res.status(204).end();
    }),
  );
  router.use('/api/v1/admin/team', owner);

  // Internal only (delivery service).
  router.get('/internal/users/riders', requireShop, handler({}, () => team.riders()));

  return router;
}
