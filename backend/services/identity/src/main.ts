import { RedisRateLimitStore, createLogger } from '@qc/common';
import { Redis } from 'ioredis';
import { createIdentityApp } from './app.js';
import { createDb } from './db.js';
import { loadIdentityEnv } from './env.js';
import { createSmsProvider } from './sms/sms-provider.js';

const env = loadIdentityEnv();
const logger = createLogger('identity', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);

const redis = new Redis(env.REDIS_URL, { maxRetriesPerRequest: 1 });
redis.on('error', (err) => logger.warn({ err }, 'redis error'));

if (env.OTP_DEV_ECHO) logger.warn('OTP_DEV_ECHO is on: OTP codes are returned in API responses (development only)');

const app = await createIdentityApp({
  db,
  logger,
  internalSecret: env.INTERNAL_HMAC_SECRET,
  sms: createSmsProvider(
    env.SMS_PROVIDER === 'msg91'
      ? { name: 'msg91', authKey: env.MSG91_AUTH_KEY!, templateId: env.MSG91_OTP_TEMPLATE_ID!, otpVariable: env.MSG91_OTP_VARIABLE }
      : { name: 'console' },
    logger,
  ),
  limits: new RedisRateLimitStore(redis),
  otpSecret: env.OTP_SECRET,
  otpDevEcho: env.OTP_DEV_ECHO,
  jwt: {
    privateKeyPem: env.JWT_PRIVATE_KEY,
    issuer: env.JWT_ISSUER,
    accessTtlSeconds: env.ACCESS_TOKEN_TTL_SECONDS,
    refreshTtlDays: env.REFRESH_TOKEN_TTL_DAYS,
  },
});

const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'identity service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    Promise.allSettled([rawPrisma.$disconnect(), redis.quit()]).finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
