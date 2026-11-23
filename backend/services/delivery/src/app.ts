import { createServiceApp, finalizeApp, internalAuth, type Logger } from '@qc/common';
import type { Express } from 'express';
import type { Db } from './db.js';
import { deliveriesRouter } from './modules/deliveries/deliveries.routes.js';
import type { DeliveriesService } from './modules/deliveries/deliveries.service.js';

export function createDeliveryApp({ db, logger, internalSecret, deliveries }: { db: Db; logger: Logger; internalSecret: string; deliveries: DeliveriesService }): Express {
  const app = createServiceApp({ service: 'delivery', logger, ready: () => db.$queryRaw`SELECT 1` });
  app.use(internalAuth(internalSecret));
  app.use(deliveriesRouter(deliveries));
  finalizeApp(app, logger);
  return app;
}
