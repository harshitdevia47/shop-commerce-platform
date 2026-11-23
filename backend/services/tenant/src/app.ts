import { createServiceApp, finalizeApp, internalAuth, type Logger } from '@qc/common';
import type { Express } from 'express';
import type { Db } from './db.js';
import { shopsRouter } from './modules/shops/shops.routes.js';
import { createShopsService } from './modules/shops/shops.service.js';

export interface TenantAppDeps {
  db: Db;
  logger: Logger;
  internalSecret: string;
}

export function createTenantApp({ db, logger, internalSecret }: TenantAppDeps): Express {
  const app = createServiceApp({
    service: 'tenant',
    logger,
    ready: () => db.$queryRaw`SELECT 1`,
  });

  // Everything below /health and /ready must come through the gateway or another service.
  app.use(internalAuth(internalSecret));
  app.use(shopsRouter(createShopsService(db)));

  finalizeApp(app, logger);
  return app;
}
