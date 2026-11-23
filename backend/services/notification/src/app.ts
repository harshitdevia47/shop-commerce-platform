import { createServiceApp, finalizeApp, type Logger } from '@qc/common';
import type { Express } from 'express';
import type { Db } from './db.js';

/** No public or internal routes: only health and readiness. Work arrives as events. */
export function createNotificationApp({ db, logger }: { db: Db; logger: Logger }): Express {
  const app = createServiceApp({ service: 'notification', logger, ready: () => db.$queryRaw`SELECT 1` });
  finalizeApp(app, logger);
  return app;
}
