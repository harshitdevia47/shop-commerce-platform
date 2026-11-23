import { createInternalClient, createLogger } from '@qc/common';
import { createConsumer, createOutboxRelay, onceOnly, prismaOutboxStore, prismaProcessedEvents } from '@qc/events';
import { Redis } from 'ioredis';
import { createDeliveryApp } from './app.js';
import { orderEventsHandler } from './consumers/order-events.js';
import { createDb } from './db.js';
import { loadDeliveryEnv } from './env.js';
import { createDeliveriesService } from './modules/deliveries/deliveries.service.js';
import { identityPort, orderPort, redisLocationStore } from './upstreams.js';

const env = loadDeliveryEnv();
const logger = createLogger('delivery', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);
const internal = (baseUrl: string) => createInternalClient({ baseUrl, secret: env.INTERNAL_HMAC_SECRET, caller: 'delivery', timeoutMs: 5000 });

const redis = new Redis(env.REDIS_URL);
const relay = createOutboxRelay({ store: prismaOutboxStore(rawPrisma), redis, logger });
const deliveries = createDeliveriesService({
  db,
  logger,
  orders: orderPort(internal(env.ORDER_URL)),
  identity: identityPort(internal(env.IDENTITY_URL)),
  locations: redisLocationStore(redis),
  events: relay,
});

const consumer = createConsumer({
  redis: redis.duplicate(),
  group: 'delivery',
  streams: ['order'],
  types: ['order.status_changed'],
  handle: onceOnly(prismaProcessedEvents(db.processedEvent), orderEventsHandler(deliveries)),
  logger,
});

const app = createDeliveryApp({ db, logger, internalSecret: env.INTERNAL_HMAC_SECRET, deliveries });
relay.start();
await consumer.start();
const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'delivery service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    Promise.allSettled([relay.stop(), consumer.stop()])
      .then(() => rawPrisma.$disconnect())
      .finally(() => {
        redis.disconnect();
        process.exit(0);
      });
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
