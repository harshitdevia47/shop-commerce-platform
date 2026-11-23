import { createInternalClient, createLogger, startIntervalJob } from '@qc/common';
import { createConsumer, onceOnly, prismaProcessedEvents } from '@qc/events';
import { Redis } from 'ioredis';
import { createCatalogApp } from './app.js';
import { orderEventsHandler } from './consumers/order-events.js';
import { createDb } from './db.js';
import { loadCatalogEnv } from './env.js';
import { sweepOrphanReservations } from './jobs/orphan-sweeper.js';
import { createStockService } from './modules/stock/stock.service.js';
import { mediaServiceResolver, tenantCatalogSettings } from './upstreams.js';

const env = loadCatalogEnv();
const logger = createLogger('catalog', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);

const internal = (baseUrl: string) => createInternalClient({ baseUrl, secret: env.INTERNAL_HMAC_SECRET, caller: 'catalog' });
const orderClient = internal(env.ORDER_URL);
const stock = createStockService(db);

const redis = new Redis(env.REDIS_URL);
const consumer = createConsumer({
  redis,
  group: 'catalog',
  streams: ['order'],
  types: ['order.placed', 'order.status_changed'],
  handle: onceOnly(prismaProcessedEvents(db.processedEvent), orderEventsHandler(stock)),
  logger,
});

const ORPHAN_AFTER_MS = 10 * 60_000;
const sweeper = startIntervalJob(
  'orphan-reservations',
  5 * 60_000,
  () =>
    sweepOrphanReservations(
      () =>
        rawPrisma.stockReservation.findMany({
          where: { committedAt: null, releasedAt: null, createdAt: { lt: new Date(Date.now() - ORPHAN_AFTER_MS) } },
          select: { shopId: true, orderId: true },
          distinct: ['shopId', 'orderId'],
          take: 200,
        }),
      { existing: async (ids) => (await orderClient.post<{ ids: string[] }>('/internal/orders/existing', { body: { ids } })).ids },
      stock,
      logger,
    ),
  logger,
);

const app = createCatalogApp({
  db,
  logger,
  internalSecret: env.INTERNAL_HMAC_SECRET,
  settings: tenantCatalogSettings(internal(env.TENANT_URL), env.SHOP_CONFIG_CACHE_SECONDS * 1000),
  media: mediaServiceResolver(internal(env.MEDIA_URL)),
});

await consumer.start();
const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'catalog service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    Promise.allSettled([consumer.stop(), sweeper.stop()])
      .then(() => rawPrisma.$disconnect())
      .finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
