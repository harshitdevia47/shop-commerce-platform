import { randomUUID } from 'node:crypto';
import type { IncomingMessage, ServerResponse } from 'node:http';
import {
  AppError,
  Errors,
  INTERNAL_HEADERS,
  INTERNAL_HEADER_PREFIX,
  errorBody,
  errorHandler,
  signInternalHeaders,
  type InternalIdentity,
  type Logger,
  type RateLimitStore,
} from '@qc/common';
import { SLUG_PATTERN } from '@qc/config-schema';
import express, { type Express, type Request, type RequestHandler } from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import { bearerToken, type AccessTokenVerifier } from './auth.js';
import { matchRoute, type RouteRule } from './routes.js';
import type { ShopResolver } from './shop-resolver.js';

export const SHOP_KEY_HEADER = 'x-shop-key';

export interface GatewayDeps {
  logger: Logger;
  routes: RouteRule[];
  shops: ShopResolver;
  verifyAccessToken: AccessTokenVerifier;
  rateLimit: { store: RateLimitStore; perMinute: number };
  internalSecret: string;
  trustProxyHops?: number;
}

interface GatewayLocals {
  route: RouteRule;
  identity: InternalIdentity;
}

function locals(res: express.Response): GatewayLocals {
  return res.locals as GatewayLocals;
}

/** Removes anything a client could use to impersonate the gateway. */
const sanitizeHeaders: RequestHandler = (req, _res, next) => {
  for (const name of Object.keys(req.headers)) {
    if (name.startsWith(INTERNAL_HEADER_PREFIX)) delete req.headers[name];
  }
  delete req.headers[INTERNAL_HEADERS.requestId];
  next();
};

export function createGatewayApp(deps: GatewayDeps): Express {
  const { logger } = deps;
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', deps.trustProxyHops ?? 0);

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'gateway' });
  });

  app.use(sanitizeHeaders);

  // 1. Route match (internal paths are never exposed).
  app.use((req, res, next) => {
    if (req.path === '/internal' || req.path.startsWith('/internal/')) throw Errors.notFound('ROUTE_NOT_FOUND');
    const route = matchRoute(deps.routes, req.path);
    if (!route) throw Errors.notFound('ROUTE_NOT_FOUND', 'Route not found');
    locals(res).route = route;
    locals(res).identity = { requestId: randomUUID(), clientIp: req.ip };
    res.setHeader(INTERNAL_HEADERS.requestId, locals(res).identity.requestId);
    next();
  });

  // 2. Shop resolution from X-Shop-Key.
  app.use(async (req, res, next) => {
    const key = req.header(SHOP_KEY_HEADER);
    if (!key) throw Errors.badRequest('SHOP_KEY_REQUIRED', 'X-Shop-Key header is required');
    if (!SLUG_PATTERN.test(key)) throw Errors.notFound('SHOP_NOT_FOUND', 'Shop not found');
    const shop = await deps.shops.resolve(key);
    if (!shop) throw Errors.notFound('SHOP_NOT_FOUND', 'Shop not found');
    if (!shop.isActive) throw Errors.forbidden('SHOP_INACTIVE', 'This shop is currently not accepting orders');
    locals(res).identity.shopId = shop.id;
    next();
  });

  // 3. Rate limit per shop + client IP (fails open if Redis is down).
  app.use(async (req, res, next) => {
    const windowIndex = Math.floor(Date.now() / 60_000);
    const key = `rl:${locals(res).identity.shopId}:${req.ip}:${windowIndex}`;
    try {
      const count = await deps.rateLimit.store.hit(key, 60);
      res.setHeader('RateLimit-Limit', deps.rateLimit.perMinute);
      res.setHeader('RateLimit-Remaining', Math.max(0, deps.rateLimit.perMinute - count));
      if (count > deps.rateLimit.perMinute) throw Errors.tooManyRequests('RATE_LIMITED', 'Too many requests');
    } catch (err) {
      if (err instanceof AppError) throw err;
      logger.warn({ err }, 'rate limiter unavailable, allowing request');
    }
    next();
  });

  // 4. Authentication / authorization.
  app.use(async (req, res, next) => {
    const { route, identity } = locals(res);
    const token = bearerToken(req.header('authorization'));
    if (token) {
      const claims = await deps.verifyAccessToken(token);
      if (claims.shopId !== identity.shopId) {
        throw Errors.forbidden('TOKEN_SHOP_MISMATCH', 'Token does not belong to this shop');
      }
      identity.userId = claims.userId;
      identity.role = claims.role;
    }
    if (route.auth === 'required' && !identity.userId) throw Errors.unauthorized('AUTH_REQUIRED', 'Login required');
    if (route.roles && (!identity.role || !route.roles.includes(identity.role))) {
      throw identity.userId ? Errors.forbidden() : Errors.unauthorized('AUTH_REQUIRED', 'Login required');
    }
    next();
  });

  // 5. Proxy with signed identity headers.
  const proxies = new Map<string, RequestHandler>();
  const proxyFor = (target: string): RequestHandler => {
    let proxy = proxies.get(target);
    if (!proxy) {
      proxy = createProxyMiddleware<Request, ServerResponse>({
        target,
        changeOrigin: true,
        xfwd: true,
        proxyTimeout: 15_000,
        on: {
          error: (err, _req, res) => {
            logger.error({ err, target }, 'upstream error');
            const response = res as ServerResponse<IncomingMessage>;
            if ('headersSent' in response && !response.headersSent) {
              response.writeHead(502, { 'content-type': 'application/json' });
              response.end(JSON.stringify(errorBody('UPSTREAM_UNAVAILABLE', 'Service temporarily unavailable')));
            }
          },
        },
      });
      proxies.set(target, proxy);
    }
    return proxy;
  };

  app.use((req, res, next) => {
    const { route, identity } = locals(res);
    delete req.headers.authorization;
    Object.assign(req.headers, signInternalHeaders(identity, deps.internalSecret));
    logger.debug({ path: req.path, shopId: identity.shopId, requestId: identity.requestId }, 'proxy');
    return proxyFor(route.target)(req, res, next);
  });

  app.use(errorHandler(logger));
  return app;
}
