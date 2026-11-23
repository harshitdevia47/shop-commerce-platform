import { cachedShopConfig, createInternalClient, createLogger } from '@qc/common';
import type { RuntimeConfig } from '@qc/config-schema';
import { createOrderApp } from './app.js';
import { createDb } from './db.js';
import { loadOrderEnv } from './env.js';
import { catalogPort, identityPort, paymentPort } from './upstreams.js';

const env = loadOrderEnv();
const logger = createLogger('order', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);
const client = (baseUrl: string) => createInternalClient({ baseUrl, secret: env.INTERNAL_HMAC_SECRET, caller: 'order', timeoutMs: 5000 });

const app = createOrderApp({
  db,
  logger,
  internalSecret: env.INTERNAL_HMAC_SECRET,
  shopConfig: cachedShopConfig<RuntimeConfig>(client(env.TENANT_URL), env.SHOP_CONFIG_CACHE_SECONDS * 1000),
  catalog: catalogPort(client(env.CATALOG_URL)),
  identity: identityPort(client(env.IDENTITY_URL)),
  payments: paymentPort(client(env.PAYMENT_URL)),
});

const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'order service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    rawPrisma.$disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
