import { cachedShopConfig, createInternalClient, createLogger, startIntervalJob } from '@qc/common';
import type { PaymentsConfig } from '@qc/config-schema';
import { createConsumer, createOutboxRelay, onceOnly, prismaOutboxStore, prismaProcessedEvents } from '@qc/events';
import { Redis } from 'ioredis';
import { createPaymentApp } from './app.js';
import { orderEventsHandler } from './consumers/order-events.js';
import { createDb } from './db.js';
import { loadPaymentEnv } from './env.js';
import { sweepOrphanPayments } from './jobs/orphan-sweeper.js';
import { createPaymentsService } from './modules/payments/payments.service.js';

const env = loadPaymentEnv();
const logger = createLogger('payment', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);
const internal = (baseUrl: string) => createInternalClient({ baseUrl, secret: env.INTERNAL_HMAC_SECRET, caller: 'payment' });
const shopConfig = cachedShopConfig<{ payments: PaymentsConfig }>(internal(env.TENANT_URL), env.SHOP_CONFIG_CACHE_SECONDS * 1000);
const orderClient = internal(env.ORDER_URL);

const redis = new Redis(env.REDIS_URL);
const relay = createOutboxRelay({ store: prismaOutboxStore(rawPrisma), redis, logger });
const payments = createPaymentsService(db, shopConfig, undefined, relay);

const consumer = createConsumer({
  redis: redis.duplicate(),
  group: 'payment',
  streams: ['order'],
  types: ['order.placed', 'order.status_changed'],
  handle: onceOnly(prismaProcessedEvents(db.processedEvent), orderEventsHandler(payments)),
  logger,
});

const ORPHAN_AFTER_MS = 10 * 60_000;
const sweeper = startIntervalJob(
  'orphan-payments',
  5 * 60_000,
  () =>
    sweepOrphanPayments(
      () =>
        rawPrisma.payment.findMany({
          where: {
            orderConfirmedAt: null,
            status: { in: ['PENDING', 'SUBMITTED'] },
            createdAt: { lt: new Date(Date.now() - ORPHAN_AFTER_MS) },
          },
          select: { shopId: true, orderId: true },
          take: 200,
        }),
      { existing: async (ids) => (await orderClient.post<{ ids: string[] }>('/internal/orders/existing', { body: { ids } })).ids },
      payments,
      logger,
    ),
  logger,
);

const app = createPaymentApp({ db, logger, internalSecret: env.INTERNAL_HMAC_SECRET, shopConfig, events: relay });

relay.start();
await consumer.start();
const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'payment service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    Promise.allSettled([relay.stop(), consumer.stop(), sweeper.stop()])
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
