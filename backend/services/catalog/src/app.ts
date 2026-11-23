import { createServiceApp, finalizeApp, internalAuth, type Logger } from '@qc/common';
import type { Express } from 'express';
import type { Db } from './db.js';
import { categoriesRouter } from './modules/categories/categories.routes.js';
import { createCategoriesService } from './modules/categories/categories.service.js';
import { productsRouter } from './modules/products/products.routes.js';
import { createProductsService } from './modules/products/products.service.js';
import type { MediaResolver, ShopCatalogSettings } from './upstreams.js';

export interface CatalogAppDeps {
  db: Db;
  logger: Logger;
  internalSecret: string;
  settings: ShopCatalogSettings;
  media: MediaResolver;
  now?: () => Date;
}

export function createCatalogApp(deps: CatalogAppDeps): Express {
  const { db, logger, now } = deps;
  const app = createServiceApp({ service: 'catalog', logger, ready: () => db.$queryRaw`SELECT 1` });

  const categories = createCategoriesService(db, deps.media, now);
  const products = createProductsService({ db, categories, settings: deps.settings, media: deps.media, now });

  app.use(internalAuth(deps.internalSecret));
  app.use(categoriesRouter(categories));
  app.use(productsRouter(products));

  finalizeApp(app, logger);
  return app;
}
