import { RedisRateLimitStore, createLogger, startIntervalJob } from '@qc/common';
import { Redis } from 'ioredis';
import { createPlatformApp } from './app.js';
import { runDailyAlerts } from './jobs/daily-alerts.js';
import { createDb } from './db.js';
import { loadPlatformEnv } from './env.js';
import { createMailer } from './mail/mailer.js';
import { createHttpShopDirectory } from './modules/subscriptions/shop-directory.js';
import { createSubscriptionsService } from './modules/subscriptions/subscriptions.service.js';

const env = loadPlatformEnv();
const logger = createLogger('platform', env.LOG_LEVEL);
const db = createDb(env.DATABASE_URL);
const redis = new Redis(env.REDIS_URL, { maxRetriesPerRequest: 1 });
redis.on('error', (err) => logger.warn({ err }, 'redis error'));

const mailer = createMailer(
  env.MAIL_PROVIDER === 'gmail' ? { provider: 'gmail', user: env.MAIL_USER!, appPassword: env.MAIL_APP_PASSWORD! } : { provider: 'console' },
  logger,
);

const directory = createHttpShopDirectory(
  { tenant: env.TENANT_URL, identity: env.IDENTITY_URL, catalog: env.CATALOG_URL, reporting: env.REPORTING_URL },
  env.INTERNAL_HMAC_SECRET,
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
  directory,
  payTo: env.PLATFORM_UPI_ID,
  defaultFeeRupees: env.PLATFORM_DEFAULT_FEE_RUPEES,
  apiTokenHash: env.PLATFORM_API_TOKEN_HASH,
});
// Hourly: date-driven state changes (paid → due) reach the shop apps; failed pushes are repaired.
const subscriptions = createSubscriptionsService({ db, directory, logger, payTo: env.PLATFORM_UPI_ID });
const pushJob = startIntervalJob('push-app-states', 60 * 60_000, () => subscriptions.pushAll(), logger);
void pushJob.runOnce();
// From 09:00 IST, one email a day about shops that became 7 days overdue (nothing is paused automatically).
const alertsJob = startIntervalJob(
  'daily-overdue-email',
  15 * 60_000,
  () => runDailyAlerts({ db, mailer, directory, now: () => new Date(), to: env.MAIL_TO ?? env.ADMIN_EMAILS[0]!, baseUrl: env.ADMIN_ORIGIN }),
  logger,
);

const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'platform admin listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  void pushJob.stop();
  void alertsJob.stop();
  server.close(() => {
    Promise.allSettled([db.$disconnect(), redis.quit()]).finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
