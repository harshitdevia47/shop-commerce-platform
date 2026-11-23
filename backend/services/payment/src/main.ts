import { cachedShopConfig, createInternalClient, createLogger } from '@qc/common';
import type { PaymentsConfig } from '@qc/config-schema';
import { createPaymentApp } from './app.js';
import { createDb } from './db.js';
import { loadPaymentEnv } from './env.js';

const env = loadPaymentEnv();
const logger = createLogger('payment', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);
const tenant = createInternalClient({ baseUrl: env.TENANT_URL, secret: env.INTERNAL_HMAC_SECRET, caller: 'payment' });

const app = createPaymentApp({
  db,
  logger,
  internalSecret: env.INTERNAL_HMAC_SECRET,
  shopConfig: cachedShopConfig<{ payments: PaymentsConfig }>(tenant, env.SHOP_CONFIG_CACHE_SECONDS * 1000),
});

const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'payment service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    rawPrisma.$disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
