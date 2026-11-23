import { createInternalClient, createLogger } from '@qc/common';
import { createCatalogApp } from './app.js';
import { createDb } from './db.js';
import { loadCatalogEnv } from './env.js';
import { mediaServiceResolver, tenantCatalogSettings } from './upstreams.js';

const env = loadCatalogEnv();
const logger = createLogger('catalog', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);

const tenant = createInternalClient({ baseUrl: env.TENANT_URL, secret: env.INTERNAL_HMAC_SECRET, caller: 'catalog' });
const media = createInternalClient({ baseUrl: env.MEDIA_URL, secret: env.INTERNAL_HMAC_SECRET, caller: 'catalog' });

const app = createCatalogApp({
  db,
  logger,
  internalSecret: env.INTERNAL_HMAC_SECRET,
  settings: tenantCatalogSettings(tenant, env.SHOP_CONFIG_CACHE_SECONDS * 1000),
  media: mediaServiceResolver(media),
});

const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'catalog service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    rawPrisma.$disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
