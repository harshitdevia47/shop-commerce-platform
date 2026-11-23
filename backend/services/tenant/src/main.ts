import { createLogger } from '@qc/common';
import { createTenantApp } from './app.js';
import { createDb } from './db.js';
import { loadTenantEnv } from './env.js';

const env = loadTenantEnv();
const logger = createLogger('tenant', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);

const app = createTenantApp({ db, logger, internalSecret: env.INTERNAL_HMAC_SECRET });
const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'tenant service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    rawPrisma
      .$disconnect()
      .catch((err: unknown) => logger.error({ err }, 'disconnect failed'))
      .finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
