import { cachedShopConfig, type InternalClient } from '@qc/common';
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

/** Tenant-backed catalog settings (cached per shop). */
export function tenantCatalogSettings(tenant: InternalClient, ttlMs: number): ShopCatalogSettings {
  const config = cachedShopConfig<{ catalog: CatalogConfig }>(tenant, ttlMs);
  return { get: async () => (await config.get()).catalog };
}

export function mediaServiceResolver(media: InternalClient): MediaResolver {
  return {
    resolve: async (ids) => (ids.length === 0 ? [] : media.post<MediaRef[]>('/internal/media/resolve', { body: { ids } })),
  };
}
