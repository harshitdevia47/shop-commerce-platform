import { createServer } from 'node:http';
import { createAccessTokenVerifier, createInternalClient, createLogger, createServiceApp, finalizeApp } from '@qc/common';
import { createConsumer } from '@qc/events';
import { Redis } from 'ioredis';
import { loadRealtimeEnv } from './env.js';
import { REALTIME_EVENTS, attachRealtime } from './realtime.js';

const env = loadRealtimeEnv();
const logger = createLogger('realtime', env.LOG_LEVEL);

// Health only over HTTP; everything else is the Socket.IO endpoint (/socket.io), proxied by nginx.
const app = createServiceApp({ service: 'realtime', logger });
finalizeApp(app, logger);
const server = createServer(app);
const delivery = createInternalClient({ baseUrl: env.DELIVERY_URL, secret: env.INTERNAL_HMAC_SECRET, caller: 'realtime' });
const { io, handle } = attachRealtime(server, {
  verify: await createAccessTokenVerifier(env.JWT_PUBLIC_KEY, env.JWT_ISSUER),
  logger,
  // Rider pings go to the delivery service in the rider's identity (it checks they are on a delivery).
  reportLocation: (identity, ping) => delivery.post('/internal/deliveries/location', { body: ping, identity }),
});

// One consumer group: run a single realtime instance (several would need the Socket.IO Redis adapter).
// Missed events while down are fine: apps re-fetch on reconnect.
const consumer = createConsumer({
  redis: new Redis(env.REDIS_URL),
  group: 'realtime',
  streams: ['order', 'payment', 'delivery'],
  types: REALTIME_EVENTS,
  handle,
  logger,
  maxAttempts: 1,
});

await consumer.start();
server.listen(env.PORT, () => logger.info({ port: env.PORT }, 'realtime service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  void io.close();
  consumer.stop().finally(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
