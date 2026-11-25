import { handler, requireShop } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import type { Db } from '../../db.js';
import { phoneSchema } from '../auth/phone.js';
import type { UsersService } from './users.service.js';

const isoDay = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
/** Shop days are IST: a day starts at 00:00 +05:30. */
const istMidnight = (day: string) => new Date(`${day}T00:00:00+05:30`);

/** Internal only (platform service): numbers and owner for the shop in the signed context. */
export function statsRouter(db: Db, users: UsersService): Router {
  const router = Router();
  router.use(['/internal/stats', '/internal/platform'], requireShop);

  router.get(
    '/internal/stats/customers',
    handler({ query: z.object({ since: isoDay }) }, async ({ query }) => {
      const since = istMidnight(query.since);
      const customers = { role: 'CUSTOMER' as const, deletedAt: null };
      const [total, newSince, activeSince] = await Promise.all([
        db.user.count({ where: customers }),
        db.user.count({ where: { ...customers, createdAt: { gte: since } } }),
        db.user.count({ where: { ...customers, lastLoginAt: { gte: since } } }),
      ]);
      return { total, newSince, activeSince };
    }),
  );

  router.get(
    '/internal/stats/owner',
    handler({}, async () => {
      const owner = await db.user.findFirst({ where: { role: 'OWNER', deletedAt: null }, orderBy: { createdAt: 'asc' } });
      return { name: owner?.name ?? null, phone: owner?.phone ?? null, hasLoggedIn: !!owner?.lastLoginAt };
    }),
  );

  router.post(
    '/internal/platform/owner',
    handler({ body: z.object({ phone: phoneSchema, name: z.string().trim().min(1).max(60).optional() }).strict() }, async ({ body }) => {
      const user = await users.upsertWithRole(body.phone, 'OWNER', body.name);
      return { id: user.id };
    }),
  );

  return router;
}
