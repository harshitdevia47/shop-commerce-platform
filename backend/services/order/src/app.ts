import { createServiceApp, finalizeApp, internalAuth, type Logger, type ShopConfigSource } from '@qc/common';
import type { RuntimeConfig } from '@qc/config-schema';
import type { Express } from 'express';
import type { Db } from './db.js';
import { ordersRouter } from './modules/orders/orders.routes.js';
import { createOrdersService } from './modules/orders/orders.service.js';
import type { CatalogPort, IdentityPort, PaymentPort } from './upstreams.js';

export interface OrderAppDeps {
  db: Db;
  logger: Logger;
  internalSecret: string;
  shopConfig: ShopConfigSource<RuntimeConfig>;
  catalog: CatalogPort;
  identity: IdentityPort;
  payments: PaymentPort;
  events?: { kick(): void };
}

export function createOrderApp(deps: OrderAppDeps): Express {
  const { db, logger } = deps;
  const app = createServiceApp({ service: 'order', logger, ready: () => db.$queryRaw`SELECT 1` });
  app.use(internalAuth(deps.internalSecret));
  app.use(ordersRouter(createOrdersService(deps)));
  finalizeApp(app, logger);
  return app;
}
