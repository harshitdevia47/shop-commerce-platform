import { createServiceApp, finalizeApp, internalAuth, type Logger } from '@qc/common';
import type { Express } from 'express';
import type { Db } from './db.js';
import { reportsRouter } from './modules/reports/reports.routes.js';
import { createReportsService } from './modules/reports/reports.service.js';

export function createReportingApp({ db, logger, internalSecret }: { db: Db; logger: Logger; internalSecret: string }): Express {
  const app = createServiceApp({ service: 'reporting', logger, ready: () => db.$queryRaw`SELECT 1` });
  app.use(internalAuth(internalSecret));
  app.use(reportsRouter(createReportsService(db)));
  finalizeApp(app, logger);
  return app;
}
