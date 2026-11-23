import { AsyncLocalStorage } from 'node:async_hooks';
import type { Role } from './roles.js';

/**
 * Per-request identity, populated from verified gateway headers (HTTP)
 * or from an event envelope (consumers). Never populated from client input.
 */
export interface RequestContext {
  requestId: string;
  shopId?: string;
  userId?: string;
  role?: Role;
  /** End-user IP as seen by the gateway (for rate limiting / audit). */
  clientIp?: string;
}

const storage = new AsyncLocalStorage<RequestContext>();

function isThenable(value: unknown): value is PromiseLike<unknown> {
  return typeof value === 'object' && value !== null && typeof (value as { then?: unknown }).then === 'function';
}

/**
 * Runs `fn` inside `context`. Lazy thenables (e.g. PrismaPromise, which only executes
 * on `.then()`) are resolved inside the context too, so
 * `await runWithContext(ctx, () => db.x.findMany())` stays scoped.
 */
export function runWithContext<T>(context: RequestContext, fn: () => T): T {
  return storage.run(context, () => {
    const result = fn();
    return (isThenable(result) ? Promise.resolve(result) : result) as T;
  });
}

export function getContext(): RequestContext | undefined {
  return storage.getStore();
}

export class TenantContextError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TenantContextError';
  }
}

/** Throws (500) when called outside a shop-scoped context: that is a programming error. */
export function requireShopId(): string {
  const shopId = storage.getStore()?.shopId;
  if (!shopId) throw new TenantContextError('Tenant context missing: shopId is required');
  return shopId;
}
