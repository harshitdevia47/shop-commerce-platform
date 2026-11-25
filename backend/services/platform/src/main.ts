import { RedisRateLimitStore, createLogger } from '@qc/common';
import { Redis } from 'ioredis';
import { createPlatformApp } from './app.js';
import { createDb } from './db.js';
import { loadPlatformEnv } from './env.js';
import { createMailer } from './mail/mailer.js';

const env = loadPlatformEnv();
const logger = createLogger('platform', env.LOG_LEVEL);
const db = createDb(env.DATABASE_URL);
const redis = new Redis(env.REDIS_URL, { maxRetriesPerRequest: 1 });
redis.on('error', (err) => logger.warn({ err }, 'redis error'));

const mailer = createMailer(
  env.MAIL_PROVIDER === 'gmail' ? { provider: 'gmail', user: env.MAIL_USER!, appPassword: env.MAIL_APP_PASSWORD! } : { provider: 'console' },
  logger,
);

const app = createPlatformApp({
  db,
  logger,
  mailer,
  limits: new RedisRateLimitStore(redis),
  loginCodeSecret: env.LOGIN_CODE_SECRET,
  admins: env.ADMIN_EMAILS,
  origin: env.ADMIN_ORIGIN,
  cookie: { secure: env.ADMIN_ORIGIN.startsWith('https://') },
});
const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'platform admin listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    Promise.allSettled([db.$disconnect(), redis.quit()]).finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
