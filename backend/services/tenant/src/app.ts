import { createServiceApp, finalizeApp, internalAuth, type Logger } from '@qc/common';
import type { Express } from 'express';
import type { Db } from './db.js';
import { legalRouter } from './modules/legal/legal.routes.js';
import type { LegalOperator } from './modules/legal/legal.pages.js';
import { shopsRouter } from './modules/shops/shops.routes.js';
import { createShopsService } from './modules/shops/shops.service.js';

export interface TenantAppDeps {
  db: Db;
  logger: Logger;
  internalSecret: string;
  /** Business that runs the apps; shown in the privacy policy and terms. */
  legal?: LegalOperator;
}

export function createTenantApp({ db, logger, internalSecret, legal = {} }: TenantAppDeps): Express {
  const app = createServiceApp({
    service: 'tenant',
    logger,
    ready: () => db.$queryRaw`SELECT 1`,
  });

  // Everything below /health and /ready must come through the gateway or another service.
  app.use(internalAuth(internalSecret));
  const shops = createShopsService(db);
  app.use(shopsRouter(shops));
  app.use(legalRouter(shops, legal));

  finalizeApp(app, logger);
  return app;
}
