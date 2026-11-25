import { pino, type Logger } from 'pino';

export type { Logger };

export function createLogger(service: string, level: string = process.env.LOG_LEVEL ?? 'info'): Logger {
  return pino({
    level,
    base: { service },
    redact: {
      paths: ['req.headers.authorization', 'req.headers["x-internal-signature"]', 'req.headers.cookie', 'res.headers["set-cookie"]'],
      censor: '[redacted]',
    },
  });
}
