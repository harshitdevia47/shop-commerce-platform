import { RedisRateLimitStore, createInternalClient, createLogger } from '@qc/common';
import { Redis } from 'ioredis';
import { createGatewayApp } from './app.js';
import { createAccessTokenVerifier } from './auth.js';
import { loadGatewayEnv } from './env.js';
import { buildRoutes } from './routes.js';
import { ShopResolver, tenantShopLookup } from './shop-resolver.js';

const env = loadGatewayEnv();
const logger = createLogger('gateway', env.LOG_LEVEL);

const redis = new Redis(env.REDIS_URL, { maxRetriesPerRequest: 1, enableOfflineQueue: false });
redis.on('error', (err) => logger.warn({ err }, 'redis error'));

const tenant = createInternalClient({ baseUrl: env.TENANT_URL, secret: env.INTERNAL_HMAC_SECRET, caller: 'gateway' });

const app = createGatewayApp({
  logger,
  routes: buildRoutes({
    tenant: env.TENANT_URL,
    identity: env.IDENTITY_URL,
    catalog: env.CATALOG_URL,
    media: env.MEDIA_URL,
    order: env.ORDER_URL,
    payment: env.PAYMENT_URL,
  }),
  mediaStaticTarget: env.MEDIA_STATIC_URL,
  shops: new ShopResolver(tenantShopLookup(tenant), env.SHOP_CACHE_TTL_SECONDS * 1000),
  verifyAccessToken: await createAccessTokenVerifier(env.JWT_PUBLIC_KEY, env.JWT_ISSUER),
  rateLimit: { store: new RedisRateLimitStore(redis), perMinute: env.RATE_LIMIT_PER_MINUTE },
  internalSecret: env.INTERNAL_HMAC_SECRET,
  trustProxyHops: env.TRUST_PROXY_HOPS,
});

const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'gateway listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    redis.quit().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
