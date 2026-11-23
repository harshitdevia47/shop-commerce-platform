import { requireShopId, type InternalClient } from '@qc/common';
import type { CatalogConfig } from '@qc/config-schema';

/** The current shop's catalog settings (variant style, axes, custom fields) from the tenant service. */
export interface ShopCatalogSettings {
  get(): Promise<CatalogConfig>;
}

/** Public image metadata from the media service. */
export interface MediaRef {
  id: string;
  url: string;
  thumbUrl: string;
}

export interface MediaResolver {
  /** Media of the current shop among `ids`; ids of other shops or unknown ids are left out. */
  resolve(ids: string[]): Promise<MediaRef[]>;
}

/** Tenant-backed settings with a short per-shop cache (settings change rarely; saves a call per write). */
export function tenantCatalogSettings(tenant: InternalClient, ttlMs: number, now: () => number = Date.now): ShopCatalogSettings {
  const cache = new Map<string, { value: CatalogConfig; expiresAt: number }>();
  return {
    async get() {
      const shopId = requireShopId();
      const hit = cache.get(shopId);
      if (hit && hit.expiresAt > now()) return hit.value;
      const config = await tenant.get<{ catalog: CatalogConfig }>('/internal/shop/config');
      cache.set(shopId, { value: config.catalog, expiresAt: now() + ttlMs });
      return config.catalog;
    },
  };
}

export function mediaServiceResolver(media: InternalClient): MediaResolver {
  return {
    resolve: async (ids) => (ids.length === 0 ? [] : media.post<MediaRef[]>('/internal/media/resolve', { body: { ids } })),
  };
}
