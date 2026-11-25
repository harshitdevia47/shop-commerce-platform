import { createServiceApp, finalizeApp, type Logger, type RateLimitStore } from '@qc/common';
import express, { type Express } from 'express';
import type { Db } from './db.js';
import type { Mailer } from './mail/mailer.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { createAuthService } from './modules/auth/auth.service.js';
import { requireAdmin, requireSameOrigin, type CookieOptions } from './modules/auth/session.js';
import type { ShopDirectory } from './modules/subscriptions/shop-directory.js';
import { shopsApiRouter } from './modules/shops-api/shops-api.routes.js';
import { pagesRouter } from './modules/subscriptions/subscriptions.routes.js';
import { createSubscriptionsService } from './modules/subscriptions/subscriptions.service.js';

export interface PlatformAppDeps {
  db: Db;
  logger: Logger;
  mailer: Mailer;
  limits: RateLimitStore;
  loginCodeSecret: string;
  admins: readonly string[];
  /** e.g. https://admin.example.in */
  origin: string;
  cookie: CookieOptions;
  /** Other services' internal APIs. */
  directory: ShopDirectory;
  /** Platform owner's UPI ID (shown to shop owners and in reminders). */
  payTo?: string;
  /** Prefilled in the "set up subscription" form. */
  defaultFeeRupees?: number;
  /** sha256 (hex) of the new-shop command's token; unset = POST /api/shops is off. */
  apiTokenHash?: string;
  now?: () => Date;
}

/**
 * The platform owner's admin site. Reached from the internet through nginx (admin.<domain>), not
 * through the gateway: every page except /login and /health needs an admin session.
 */
export function createPlatformApp(deps: PlatformAppDeps): Express {
  const { db, logger } = deps;
  const app = createServiceApp({ service: 'platform', logger, ready: () => db.$queryRaw`SELECT 1` });
  app.set('trust proxy', 1); // nginx in front: req.ip is the visitor
  app.use(express.urlencoded({ extended: false, limit: '20kb' }));
  app.use(requireSameOrigin(deps.origin));

  const auth = createAuthService({ db, mailer: deps.mailer, limits: deps.limits, logger, secret: deps.loginCodeSecret, admins: deps.admins, now: deps.now });
  app.use(authRouter(auth, deps.cookie));

  const admin = requireAdmin(auth, deps.cookie);
  const subscriptions = createSubscriptionsService({ db, directory: deps.directory, logger, payTo: deps.payTo, now: deps.now });
  app.use(shopsApiRouter({ directory: deps.directory, subscriptions, apiTokenHash: deps.apiTokenHash }));
  app.use(pagesRouter({ subscriptions, directory: deps.directory, admin, logger, payTo: deps.payTo, defaultFeeRupees: deps.defaultFeeRupees, now: deps.now }));

  finalizeApp(app, logger);
  return app;
}
