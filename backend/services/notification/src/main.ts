import { cachedShopConfig, createInternalClient, createLogger, startIntervalJob } from '@qc/common';
import type { RuntimeConfig } from '@qc/config-schema';
import { createConsumer, onceOnly, prismaProcessedEvents } from '@qc/events';
import { Redis } from 'ioredis';
import { createNotificationApp } from './app.js';
import { createDb } from './db.js';
import { loadNotificationEnv } from './env.js';
import { NOTIFIED_EVENTS, createNotifier, type PushTarget } from './notifier.js';
import { consolePushSender, fcmPushSender } from './push/push-sender.js';

const env = loadNotificationEnv();
const logger = createLogger('notification', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);
const internal = (baseUrl: string) => createInternalClient({ baseUrl, secret: env.INTERNAL_HMAC_SECRET, caller: 'notification' });
const identity = internal(env.IDENTITY_URL);

const push = env.PUSH_PROVIDER === 'fcm' ? fcmPushSender(env.FCM_SERVICE_ACCOUNT!, logger) : consolePushSender(logger);
if (push.name === 'console' && env.NODE_ENV === 'production') logger.warn('PUSH_PROVIDER=console in production: no pushes reach phones');

const consumer = createConsumer({
  redis: new Redis(env.REDIS_URL),
  group: 'notification',
  streams: ['order', 'payment'],
  types: NOTIFIED_EVENTS,
  handle: onceOnly(
    prismaProcessedEvents(db.processedEvent),
    createNotifier({
      shopConfig: cachedShopConfig<RuntimeConfig>(internal(env.TENANT_URL), env.SHOP_CONFIG_CACHE_SECONDS * 1000),
      devices: {
        targets: (query) => identity.post<PushTarget[]>('/internal/devices/targets', { body: query }),
        remove: async (tokens) => {
          await identity.post('/internal/devices/remove', { body: { tokens } });
        },
      },
      push,
      logger,
    }),
  ),
  logger,
});

// Duplicates only arrive within minutes of the original; keep a week of history.
const prune = startIntervalJob(
  'prune-processed-events',
  6 * 60 * 60_000,
  () => rawPrisma.processedEvent.deleteMany({ where: { processedAt: { lt: new Date(Date.now() - 7 * 24 * 60 * 60_000) } } }),
  logger,
);

const app = createNotificationApp({ db, logger });
await consumer.start();
const server = app.listen(env.PORT, () => logger.info({ port: env.PORT, push: push.name }, 'notification service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    Promise.allSettled([consumer.stop(), prune.stop()])
      .then(() => rawPrisma.$disconnect())
      .finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
