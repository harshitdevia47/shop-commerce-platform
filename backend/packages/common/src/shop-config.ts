import { requireShopId } from './context.js';
import type { InternalClient } from './internal-client.js';

export interface ShopConfigSource<T> {
  /** Runtime config of the shop in the current context. */
  get(): Promise<T>;
}

/**
 * Reads the current shop's runtime config from tenant `GET /internal/shop/config`, cached per shop.
 * Settings change rarely; a short TTL saves a call per request. `T` is usually `PublicShopConfig`.
 */
export function cachedShopConfig<T>(tenant: InternalClient, ttlMs: number, now: () => number = Date.now): ShopConfigSource<T> {
  const cache = new Map<string, { value: T; expiresAt: number }>();
  return {
    async get() {
      const shopId = requireShopId();
      const hit = cache.get(shopId);
      if (hit && hit.expiresAt > now()) return hit.value;
      const value = await tenant.get<T>('/internal/shop/config');
      cache.set(shopId, { value, expiresAt: now() + ttlMs });
      return value;
    },
  };
}
