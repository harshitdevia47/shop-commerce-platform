import { resolve } from 'node:path';
import { createLogger } from '@qc/common';
import { createMediaApp } from './app.js';
import { createDb } from './db.js';
import { loadMediaEnv } from './env.js';

const env = loadMediaEnv();
const logger = createLogger('media', env.LOG_LEVEL);
const { rawPrisma, db } = createDb(env.DATABASE_URL);

if (env.MEDIA_SERVE_STATIC && env.NODE_ENV === 'production') {
  logger.warn('MEDIA_SERVE_STATIC is on in production; nginx should serve /media instead');
}

const app = createMediaApp({
  db,
  logger,
  internalSecret: env.INTERNAL_HMAC_SECRET,
  root: resolve(env.MEDIA_ROOT),
  publicPath: env.MEDIA_PUBLIC_PATH,
  maxUploadBytes: env.MAX_UPLOAD_BYTES,
  serveStatic: env.MEDIA_SERVE_STATIC,
});

const server = app.listen(env.PORT, () => logger.info({ port: env.PORT }, 'media service listening'));

function shutdown(signal: string): void {
  logger.info({ signal }, 'shutting down');
  server.close(() => {
    rawPrisma.$disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
