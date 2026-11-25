import { randomUUID } from 'node:crypto';
import { createInternalClient, type Logger } from '@qc/common';
import type { SubscriptionState } from '@qc/config-schema';

export interface ShopSummary {
  id: string;
  slug: string;
  name: string;
  businessType: string;
  contact: { phone: string; whatsapp?: string; address: string };
  isActive: boolean;
  createdAt: string;
}

/** Numbers from the other services; a part is null when that service did not answer. */
export interface ShopNumbers {
  customers: { total: number; newSince: number; activeSince: number } | null;
  owner: { name: string | null; phone: string | null; hasLoggedIn: boolean } | null;
  products: number | null;
  month: { orders: number; salesPaise: number; lastOrderAt: string | null } | null;
}

/** Everything the platform needs from the other services (their internal APIs, never their DBs). */
export interface ShopDirectory {
  list(): Promise<ShopSummary[]>;
  /** `monthStart` = first day of the current month, YYYY-MM-DD. */
  numbers(shopId: string, monthStart: string): Promise<ShopNumbers>;
  pushState(shopId: string, state: SubscriptionState): Promise<void>;
  sync(clientJson: unknown): Promise<{ id: string; slug: string; created: boolean }>;
  createOwner(shopId: string, phone: string, name?: string): Promise<void>;
}

export interface DirectoryUrls {
  tenant: string;
  identity: string;
  catalog: string;
  reporting: string;
}

export function createHttpShopDirectory(urls: DirectoryUrls, secret: string, logger: Logger): ShopDirectory {
  const client = (baseUrl: string) => createInternalClient({ baseUrl, secret, caller: 'platform', timeoutMs: 5000 });
  const tenant = client(urls.tenant);
  const identity = client(urls.identity);
  const catalog = client(urls.catalog);
  const reporting = client(urls.reporting);
  const inShop = (shopId: string) => ({ identity: { requestId: randomUUID(), shopId } });
  const noShop = () => ({ identity: { requestId: randomUUID() } });

  async function part<T>(name: string, shopId: string, fn: () => Promise<T>): Promise<T | null> {
    try {
      return await fn();
    } catch (err) {
      logger.warn({ err, shopId, part: name }, 'shop numbers: a service did not answer');
      return null;
    }
  }

  return {
    list: () => tenant.get<ShopSummary[]>('/internal/platform/shops', noShop()),

    async numbers(shopId, monthStart) {
      const q = encodeURIComponent(monthStart);
      const [customers, owner, products, month] = await Promise.all([
        part('customers', shopId, () => identity.get<ShopNumbers['customers']>(`/internal/stats/customers?since=${q}`, inShop(shopId))),
        part('owner', shopId, () => identity.get<ShopNumbers['owner']>('/internal/stats/owner', inShop(shopId))),
        part('products', shopId, async () => (await catalog.get<{ count: number }>('/internal/stats/products', inShop(shopId))).count),
        part('month', shopId, () => reporting.get<ShopNumbers['month']>(`/internal/stats/month?from=${q}`, inShop(shopId))),
      ]);
      return { customers, owner, products, month };
    },

    async pushState(shopId, state) {
      await tenant.put<void>(`/internal/platform/shops/${encodeURIComponent(shopId)}/subscription`, { ...noShop(), body: state });
    },

    sync: (clientJson) => tenant.post('/internal/platform/shops/sync', { ...noShop(), body: clientJson }),

    async createOwner(shopId, phone, name) {
      await identity.post('/internal/platform/owner', { ...inShop(shopId), body: { phone, ...(name ? { name } : {}) } });
    },
  };
}
