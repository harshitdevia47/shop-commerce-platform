import { createHmac, timingSafeEqual } from 'node:crypto';
import type { IncomingHttpHeaders } from 'node:http';
import type { RequestHandler } from 'express';
import { getContext, runWithContext, type RequestContext } from './context.js';
import { AppError, Errors } from './errors.js';
import { ADMIN_ROLES, isRole, type Role } from './roles.js';

/**
 * Headers the gateway (or a calling service) attaches to internal requests.
 * The gateway strips any client-supplied copies before signing.
 */
export const INTERNAL_HEADERS = {
  shopId: 'x-internal-shop-id',
  userId: 'x-internal-user-id',
  role: 'x-internal-role',
  timestamp: 'x-internal-ts',
  signature: 'x-internal-signature',
  requestId: 'x-request-id',
} as const;

export const INTERNAL_HEADER_PREFIX = 'x-internal-';

export type InternalIdentity = RequestContext;

const MAX_CLOCK_SKEW_SECONDS = 60;

function canonical(identity: InternalIdentity, timestamp: string): string {
  return [identity.requestId, identity.shopId ?? '', identity.userId ?? '', identity.role ?? '', timestamp].join('|');
}

function hmac(secret: string, data: string): Buffer {
  return createHmac('sha256', secret).update(data).digest();
}

export function signInternalHeaders(
  identity: InternalIdentity,
  secret: string,
  nowMs: number = Date.now(),
): Record<string, string> {
  const timestamp = String(Math.floor(nowMs / 1000));
  const headers: Record<string, string> = {
    [INTERNAL_HEADERS.requestId]: identity.requestId,
    [INTERNAL_HEADERS.timestamp]: timestamp,
    [INTERNAL_HEADERS.signature]: hmac(secret, canonical(identity, timestamp)).toString('hex'),
  };
  if (identity.shopId) headers[INTERNAL_HEADERS.shopId] = identity.shopId;
  if (identity.userId) headers[INTERNAL_HEADERS.userId] = identity.userId;
  if (identity.role) headers[INTERNAL_HEADERS.role] = identity.role;
  return headers;
}

function single(headers: IncomingHttpHeaders, name: string): string | undefined {
  const value = headers[name];
  if (Array.isArray(value)) throw new AppError('INTERNAL_AUTH_INVALID', 401, `Duplicate header ${name}`);
  return value === '' ? undefined : value;
}

export function verifyInternalHeaders(
  headers: IncomingHttpHeaders,
  secret: string,
  nowMs: number = Date.now(),
): InternalIdentity {
  const requestId = single(headers, INTERNAL_HEADERS.requestId);
  const timestamp = single(headers, INTERNAL_HEADERS.timestamp);
  const signature = single(headers, INTERNAL_HEADERS.signature);
  if (!requestId || !timestamp || !signature) {
    throw new AppError('INTERNAL_AUTH_MISSING', 401, 'Missing internal authentication');
  }

  const ts = Number(timestamp);
  if (!Number.isInteger(ts) || Math.abs(nowMs / 1000 - ts) > MAX_CLOCK_SKEW_SECONDS) {
    throw new AppError('INTERNAL_AUTH_EXPIRED', 401, 'Internal authentication expired');
  }

  const role = single(headers, INTERNAL_HEADERS.role);
  if (role !== undefined && !isRole(role)) {
    throw new AppError('INTERNAL_AUTH_INVALID', 401, 'Invalid role');
  }

  const identity: InternalIdentity = {
    requestId,
    shopId: single(headers, INTERNAL_HEADERS.shopId),
    userId: single(headers, INTERNAL_HEADERS.userId),
    role,
  };

  const expected = hmac(secret, canonical(identity, timestamp));
  const given = Buffer.from(signature, 'hex');
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
    throw new AppError('INTERNAL_AUTH_INVALID', 401, 'Invalid internal signature');
  }
  return identity;
}

/** Verifies gateway/service signature and runs the rest of the chain inside that identity's context. */
export function internalAuth(secret: string): RequestHandler {
  return (req, _res, next) => {
    const identity = verifyInternalHeaders(req.headers, secret);
    runWithContext(identity, () => next());
  };
}

export const requireShop: RequestHandler = (_req, _res, next) => {
  if (!getContext()?.shopId) throw Errors.badRequest('SHOP_REQUIRED', 'Shop context is required');
  next();
};

export function requireRole(...roles: Role[]): RequestHandler {
  return (_req, _res, next) => {
    const context = getContext();
    if (!context?.userId) throw Errors.unauthorized('AUTH_REQUIRED', 'Login required');
    if (!context.role || !roles.includes(context.role)) throw Errors.forbidden();
    next();
  };
}

export const requireAdmin: RequestHandler = requireRole(...ADMIN_ROLES);
