import { LOCALES } from '@qc/config-schema';
import { getContext, handler, requireUser } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import { toPublicUser, type UsersService } from './users.service.js';

export function usersRouter(users: UsersService): Router {
  const router = Router();
  router.use('/api/v1/me', requireUser);

  router.get(
    '/api/v1/me',
    handler({}, async () => toPublicUser(await users.getById(getContext()!.userId!))),
  );

  router.patch(
    '/api/v1/me',
    handler(
      {
        body: z
          .object({
            name: z.string().trim().min(1).max(60).optional(),
            locale: z.enum(LOCALES).optional(),
          })
          .strict()
          .refine((b) => Object.keys(b).length > 0, { message: 'Nothing to update' }),
      },
      async ({ body }) => toPublicUser(await users.updateProfile(getContext()!.userId!, body)),
    ),
  );

  return router;
}
