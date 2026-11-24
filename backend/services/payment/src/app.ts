import { createServiceApp, finalizeApp, internalAuth, type Logger, type ShopConfigSource } from '@qc/common';
import type { PaymentsConfig } from '@qc/config-schema';
import type { Express } from 'express';
import type { Db } from './db.js';
import { paymentsRouter } from './modules/payments/payments.routes.js';
import { createPaymentsService, type RazorpayDeps } from './modules/payments/payments.service.js';

export interface PaymentAppDeps {
  db: Db;
  logger: Logger;
  internalSecret: string;
  shopConfig: ShopConfigSource<{ slug?: string; payments: PaymentsConfig }>;
  now?: () => Date;
  events?: { kick(): void };
  razorpay?: RazorpayDeps;
}

export function createPaymentApp(deps: PaymentAppDeps): Express {
  const { db, logger } = deps;
  const app = createServiceApp({ service: 'payment', logger, ready: () => db.$queryRaw`SELECT 1` });
  app.use(internalAuth(deps.internalSecret));
  app.use(paymentsRouter(createPaymentsService(db, deps.shopConfig, deps.now, deps.events, deps.razorpay)));
  finalizeApp(app, logger);
  return app;
}
