import { AppError, type InternalClient } from '@qc/common';

export interface ShopRef {
  id: string;
  slug: string;
  isActive: boolean;
}

export type ShopLookup = (slug: string) => Promise<ShopRef | null>;

interface CacheEntry {
  value: ShopRef | null;
  expiresAt: number;
}

/**
 * Resolves X-Shop-Key (slug) -> shop, with an in-memory TTL cache.
 * Unknown slugs are cached briefly too, so random keys cannot hammer the tenant service.
 * Concurrent lookups for the same slug share one upstream request.
 */
export class ShopResolver {
  private readonly cache = new Map<string, CacheEntry>();
  private readonly inflight = new Map<string, Promise<ShopRef | null>>();

  constructor(
    private readonly lookup: ShopLookup,
    private readonly ttlMs: number,
    private readonly negativeTtlMs = 10_000,
    private readonly maxEntries = 1_000,
    private readonly now: () => number = Date.now,
  ) {}

  resolve(slug: string): Promise<ShopRef | null> {
    const hit = this.cache.get(slug);
    if (hit && hit.expiresAt > this.now()) return Promise.resolve(hit.value);

    let pending = this.inflight.get(slug);
    if (!pending) {
      pending = this.lookup(slug)
        .then((value) => {
          if (this.cache.size >= this.maxEntries) {
            const oldest = this.cache.keys().next().value;
            if (oldest !== undefined) this.cache.delete(oldest);
          }
          this.cache.set(slug, { value, expiresAt: this.now() + (value ? this.ttlMs : this.negativeTtlMs) });
          return value;
        })
        .finally(() => this.inflight.delete(slug));
      this.inflight.set(slug, pending);
    }
    return pending;
  }
}

export function tenantShopLookup(tenant: InternalClient): ShopLookup {
  return async (slug) => {
    try {
      return await tenant.get<ShopRef>(`/internal/shops/by-slug/${encodeURIComponent(slug)}`, {
        identity: { requestId: `gateway-shop-lookup-${slug}` },
      });
    } catch (err) {
      if (err instanceof AppError && err.status === 404) return null;
      throw err;
    }
  };
}
