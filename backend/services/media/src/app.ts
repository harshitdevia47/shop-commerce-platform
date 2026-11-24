import { join } from 'node:path';
import { createServiceApp, finalizeApp, internalAuth, type Logger, type ShopConfigSource } from '@qc/common';
import type { Features } from '@qc/config-schema';
import express, { type Express } from 'express';
import type { Db } from './db.js';
import { mediaRouter } from './modules/media/media.routes.js';
import { createMediaService } from './modules/media/media.service.js';

export interface MediaAppDeps {
  db: Db;
  logger: Logger;
  internalSecret: string;
  root: string;
  publicPath: string;
  maxUploadBytes: number;
  /** Dev only: serve public files at `publicPath` (nginx does this in production). */
  serveStatic?: boolean;
  shopConfig?: ShopConfigSource<{ features: Features }>;
  now?: () => Date;
}

export function createMediaApp(deps: MediaAppDeps): Express {
  const { db, logger } = deps;
  const app = createServiceApp({ service: 'media', logger, ready: () => db.$queryRaw`SELECT 1` });

  if (deps.serveStatic) {
    // Public renditions only; never the private folder. Mounted before internalAuth: no headers needed.
    app.use(
      deps.publicPath,
      express.static(join(deps.root, 'public'), { immutable: true, maxAge: '30d', index: false, dotfiles: 'deny' }),
    );
  }

  const media = createMediaService({ db, root: deps.root, publicPath: deps.publicPath, shopConfig: deps.shopConfig, now: deps.now });
  app.use(internalAuth(deps.internalSecret));
  app.use(mediaRouter(media, deps.maxUploadBytes));

  finalizeApp(app, logger);
  return app;
}
