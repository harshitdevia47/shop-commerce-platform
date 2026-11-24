import { randomUUID } from 'node:crypto';
import express, { type Express } from 'express';
import type { Logger } from 'pino';
import { pinoHttp } from 'pino-http';
import { errorHandler, notFoundHandler } from './errors.js';
import { INTERNAL_HEADERS } from './internal-auth.js';

/** Request with the unparsed JSON body (set by the JSON parser of `createServiceApp`). */
export interface RawBodyRequest extends express.Request {
  rawBody?: Buffer;
}

export interface ServiceAppOptions {
  service: string;
  logger: Logger;
  /** Throws when the service cannot serve traffic (e.g. DB unreachable). */
  ready?: () => Promise<unknown>;
  jsonLimit?: string;
}

/** Base Express app every service starts from: health, readiness, request logging, JSON parsing. */
export function createServiceApp({ service, logger, ready, jsonLimit = '1mb' }: ServiceAppOptions): Express {
  const app = express();
  app.disable('x-powered-by');

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service });
  });

  app.get('/ready', async (_req, res) => {
    try {
      await ready?.();
      res.json({ status: 'ready', service });
    } catch (err) {
      logger.warn({ err }, 'Readiness check failed');
      res.status(503).json({ status: 'not_ready', service });
    }
  });

  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => {
        const header = req.headers[INTERNAL_HEADERS.requestId];
        return typeof header === 'string' && header ? header : randomUUID();
      },
    }),
  );
  // Keep the exact bytes too: webhook signatures (Razorpay) are computed over the raw body.
  app.use(
    express.json({
      limit: jsonLimit,
      verify: (req, _res, buf) => {
        (req as RawBodyRequest).rawBody = buf;
      },
    }),
  );
  return app;
}

/** Call after registering routes. */
export function finalizeApp(app: Express, logger: Logger): void {
  app.use(notFoundHandler);
  app.use(errorHandler(logger));
}
