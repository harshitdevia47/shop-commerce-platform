import { Errors, handler, requireAdmin, requireRole, requireShop } from '@qc/common';
import { SLUG_PATTERN } from '@qc/config-schema';
import { Router } from 'express';
import { z } from 'zod';
import { ownerSettingsPatchSchema, type ShopsService } from './shops.service.js';

export function shopsRouter(shops: ShopsService): Router {
  const router = Router();

  // Public (via gateway): runtime config for the app of the shop in X-Shop-Key.
  router.get(
    '/api/v1/shop/config',
    requireShop,
    handler({}, () => shops.getCurrentConfig()),
  );

  // Shop settings screen: staff may look, only the owner changes them.
  router.get('/api/v1/admin/settings', requireAdmin, requireShop, handler({}, () => shops.getCurrentConfig()));
  router.patch(
    '/api/v1/admin/settings',
    requireRole('OWNER'),
    requireShop,
    handler({ body: ownerSettingsPatchSchema }, ({ body }) => shops.updateOwnerSettings(body)),
  );

  // Internal: runtime config of the shop in the signed context (catalog validates custom fields with it).
  router.get(
    '/internal/shop/config',
    requireShop,
    handler({}, () => shops.getCurrentConfig()),
  );

  // Internal: gateway resolves X-Shop-Key -> shop id.
  router.get(
    '/internal/shops/by-slug/:slug',
    handler({ params: z.object({ slug: z.string().regex(SLUG_PATTERN) }) }, async ({ params }) => {
      const shop = await shops.findRefBySlug(params.slug);
      if (!shop) throw Errors.notFound('SHOP_NOT_FOUND', 'Shop not found');
      return shop;
    }),
  );

  return router;
}
