import { createLogger } from '@qc/common';
import { createConsumer, onceOnly, prismaProcessedEvents } from '@qc/events';
import { Redis } from 'ioredis';
import { createReportingApp } from './app.js';
import { PROJECTED_EVENTS, salesProjector } from './consumers/sales-projector.js';
import { createDb } from './db.js';
import { loadReportingEnv } from './env.js';

const env = loadReportingEnv();
const logger = createLogger('reporting', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);

// Starts from the beginning of the streams the first time: a new reporting service catches up on
// every order still in Redis (streams keep about 100 000 events each). Replays are idempotent.
const consumer = createConsumer({
  redis: new Redis(env.REDIS_URL),
  group: 'reporting',
  streams: ['order', 'payment'],
  types: PROJECTED_EVENTS,
  handle: onceOnly(prismaProcessedEvents(db.processedEvent), salesProjector(db)),
  logger,
  startId: '0',
});

const app = createReportingApp({ db, logger, internalSecret: env.INTERNAL_HMAC_SECRET });
await consumer.start();
const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'reporting service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    consumer
      .stop()
      .then(() => rawPrisma.$disconnect())
      .finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
