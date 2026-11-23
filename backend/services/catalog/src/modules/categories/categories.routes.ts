import { handler, requireAdmin, requireShop } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import { i18nInput, idParams, nameInput } from '../shared/schemas.js';
import type { CategoriesService } from './categories.service.js';

const categoryBody = z
  .object({
    name: nameInput,
    nameI18n: i18nInput,
    parentId: z.uuid().nullable().optional(),
    imageMediaId: z.uuid().nullable().optional(),
    sortOrder: z.number().int().min(0).max(100_000).optional(),
    isActive: z.boolean().optional(),
  })
  .strict();

export function categoriesRouter(categories: CategoriesService): Router {
  const router = Router();

  router.get('/api/v1/catalog/categories', requireShop, handler({}, () => categories.listPublic()));

  const admin = Router();
  admin.use(requireAdmin, requireShop);
  admin.get('/', handler({}, () => categories.listAll()));
  admin.post('/', handler({ body: categoryBody }, ({ body }) => categories.create(body), 201));
  admin.patch(
    '/:id',
    handler(
      {
        params: idParams,
        body: categoryBody.partial().refine((b) => Object.keys(b).length > 0, { message: 'Nothing to update' }),
      },
      ({ params, body }) => categories.update(params.id, body),
    ),
  );
  admin.delete(
    '/:id',
    handler({ params: idParams }, async ({ params }, _req, res) => {
      await categories.remove(params.id);
      res.status(204).end();
    }),
  );
  router.use('/api/v1/admin/catalog/categories', admin);

  return router;
}
