import { handler, requireAdmin, requireShop } from '@qc/common';
import { Router } from 'express';
import { z } from 'zod';
import { i18nInput, idParams, nameInput, pageQuery } from '../shared/schemas.js';
import { MAX_IMAGES, MAX_VARIANTS } from './product-rules.js';
import type { ProductsService } from './products.service.js';

const MAX_PAISE = 100_000_000; // ₹10,00,000 per item is plenty for a local shop
const paise = z.number().int().min(0).max(MAX_PAISE);

const variantBody = z
  .object({
    id: z.uuid().optional(),
    label: z.string().trim().max(60).optional(),
    labelI18n: i18nInput,
    options: z.record(z.string(), z.string().trim().min(1).max(40)).optional(),
    sku: z.string().trim().max(60).nullable().optional(),
    pricePaise: paise,
    mrpPaise: paise.nullable().optional(),
    stockQty: z.number().int().min(0).max(1_000_000).nullable().optional(),
    isAvailable: z.boolean().optional(),
  })
  .strict();

const productBody = z
  .object({
    name: nameInput,
    nameI18n: i18nInput,
    description: z.string().trim().max(4000).nullable().optional(),
    descriptionI18n: i18nInput,
    categoryId: z.uuid().nullable().optional(),
    customFields: z.record(z.string(), z.union([z.string().max(500), z.number(), z.boolean()])).optional(),
    tags: z.array(z.string().trim().min(1).max(40)).max(20).optional(),
    imageMediaIds: z.array(z.uuid()).max(MAX_IMAGES).optional(),
    isActive: z.boolean().optional(),
    sortOrder: z.number().int().min(0).max(100_000).optional(),
    variants: z.array(variantBody).min(1).max(MAX_VARIANTS),
  })
  .strict();

const publicQuery = z.object({
  ...pageQuery,
  categoryId: z.uuid().optional(),
  q: z.string().trim().max(60).optional(),
});

export function productsRouter(products: ProductsService): Router {
  const router = Router();

  router.get('/api/v1/catalog/products', requireShop, handler({ query: publicQuery }, ({ query }) => products.listPublic(query)));
  router.get('/api/v1/catalog/products/:id', requireShop, handler({ params: idParams }, ({ params }) => products.getPublic(params.id)));

  const admin = Router();
  admin.use(requireAdmin, requireShop);
  admin.get(
    '/products',
    handler(
      { query: publicQuery.extend({ status: z.enum(['active', 'inactive', 'all']).default('all') }) },
      ({ query }) => products.listAdmin(query),
    ),
  );
  admin.post('/products', handler({ body: productBody }, ({ body }) => products.create(body), 201));
  admin.get('/products/:id', handler({ params: idParams }, ({ params }) => products.getAdmin(params.id)));
  admin.put('/products/:id', handler({ params: idParams, body: productBody }, ({ params, body }) => products.replace(params.id, body)));
  admin.patch(
    '/products/:id',
    handler({ params: idParams, body: z.object({ isActive: z.boolean() }).strict() }, ({ params, body }) =>
      products.setActive(params.id, body.isActive),
    ),
  );
  admin.delete(
    '/products/:id',
    handler({ params: idParams }, async ({ params }, _req, res) => {
      await products.remove(params.id);
      res.status(204).end();
    }),
  );
  admin.patch(
    '/variants/:id',
    handler(
      {
        params: idParams,
        body: z
          .object({
            pricePaise: paise.optional(),
            mrpPaise: paise.nullable().optional(),
            stockQty: z.number().int().min(0).max(1_000_000).nullable().optional(),
            isAvailable: z.boolean().optional(),
          })
          .strict()
          .refine((b) => Object.keys(b).length > 0, { message: 'Nothing to update' }),
      },
      ({ params, body }) => products.updateVariant(params.id, body),
    ),
  );
  router.use('/api/v1/admin/catalog', admin);

  // Internal (platform service): product count for the shop in the signed context.
  router.get('/internal/stats/products', requireShop, handler({}, () => products.count()));

  return router;
}
