import { createHash, timingSafeEqual } from 'node:crypto';
import { AppError, Errors, handler } from '@qc/common';
import { Router, type NextFunction, type Request, type Response } from 'express';
import { z } from 'zod';
import type { ShopDirectory } from '../subscriptions/shop-directory.js';
import type { SubscriptionsService } from '../subscriptions/subscriptions.service.js';

const sha256 = (value: string) => createHash('sha256').update(value).digest();

/** Bearer token of the laptop's new-shop command; only its sha256 is configured on the server. */
function requireApiToken(hashHex: string | undefined) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!hashHex) return next(Errors.notFound('ROUTE_NOT_FOUND', 'Route not found'));
    const token = /^Bearer (.+)$/.exec(req.headers.authorization ?? '')?.[1];
    if (!token || !timingSafeEqual(sha256(token), Buffer.from(hashHex, 'hex'))) {
      return next(new AppError('API_TOKEN_INVALID', 401, 'Invalid platform token'));
    }
    next();
  };
}

const body = z
  .object({
    /** client.json as written by new-shop (tenant validates it). */
    clientJson: z.record(z.string(), z.unknown()),
    ownerPhone: z.string().min(10).max(20),
    ownerName: z.string().trim().min(1).max(60).optional(),
    feePaise: z.number().int().positive().max(10_000_000),
    dueDay: z.number().int().min(1).max(28),
  })
  .strict();

/**
 * `npm run new-shop` on the laptop: creates or updates the shop in tenant, its owner in identity and
 * (first time only) its subscription, so nobody has to log into the server.
 */
export function shopsApiRouter(deps: { directory: ShopDirectory; subscriptions: SubscriptionsService; apiTokenHash?: string }): Router {
  const router = Router();
  router.post(
    '/api/shops',
    requireApiToken(deps.apiTokenHash),
    handler({ body }, async ({ body: input }) => {
      const shop = await deps.directory.sync(input.clientJson);
      await deps.directory.createOwner(shop.id, input.ownerPhone, input.ownerName);
      const existing = await deps.subscriptions.get(shop.id);
      if (!existing.subscription) await deps.subscriptions.setup(shop.id, { feePaise: input.feePaise, dueDay: input.dueDay });
      const { subscription } = await deps.subscriptions.get(shop.id);
      return {
        shopId: shop.id,
        slug: shop.slug,
        created: shop.created,
        subscription: existing.subscription ? 'kept' : 'created',
        nextDueDate: subscription?.nextDueDate ?? null,
      };
    }),
  );
  return router;
}
