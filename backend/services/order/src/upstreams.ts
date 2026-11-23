import type { InternalClient } from '@qc/common';

/** Catalog's view of a variant (POST /internal/catalog/variants/lookup). */
export interface VariantSnapshot {
  variantId: string;
  productId: string;
  productName: string;
  productNameI18n: Record<string, string> | null;
  label: string;
  labelI18n: Record<string, string> | null;
  pricePaise: number;
  mrpPaise: number | null;
  thumbUrl: string | null;
  inStock: boolean;
  stockQty: number | null;
}

export interface CheckoutAddress {
  id: string;
  label: string;
  name: string | null;
  phone: string | null;
  line1: string;
  line2: string | null;
  landmark: string | null;
  city: string;
  pincode: string;
  lat: number | null;
  lng: number | null;
}

export interface CheckoutProfile {
  user: { id: string; phone: string; name: string | null; isBlocked: boolean };
  address: CheckoutAddress | null;
}

export interface PaymentView {
  id: string;
  orderId: string;
  method: 'COD' | 'UPI';
  status: 'PENDING' | 'SUBMITTED' | 'PAID' | 'VOID';
  amountPaise: number;
  upiUri?: string;
}

/** Everything the order saga calls. Interfaces so tests can use fakes. */
export interface CatalogPort {
  lookup(ids: string[]): Promise<VariantSnapshot[]>;
  reserve(orderId: string, items: { variantId: string; qty: number }[]): Promise<void>;
  release(orderId: string): Promise<void>;
}

export interface IdentityPort {
  checkoutProfile(userId: string, addressId?: string): Promise<CheckoutProfile>;
}

export interface PaymentPort {
  create(input: { orderId: string; orderNumber: number; customerId: string; method: 'COD' | 'UPI'; amountPaise: number }): Promise<PaymentView>;
  void(orderId: string): Promise<void>;
}

export function catalogPort(client: InternalClient): CatalogPort {
  return {
    lookup: (ids) => (ids.length === 0 ? Promise.resolve([]) : client.post('/internal/catalog/variants/lookup', { body: { ids } })),
    reserve: async (orderId, items) => {
      await client.post('/internal/catalog/stock/reserve', { body: { orderId, items } });
    },
    release: async (orderId) => {
      await client.post('/internal/catalog/stock/release', { body: { orderId } });
    },
  };
}

export function identityPort(client: InternalClient): IdentityPort {
  return {
    checkoutProfile: (userId, addressId) =>
      client.get(`/internal/users/${userId}/checkout${addressId ? `?addressId=${addressId}` : ''}`),
  };
}

export function paymentPort(client: InternalClient): PaymentPort {
  return {
    create: (input) => client.post('/internal/payments', { body: input }),
    void: async (orderId) => {
      await client.post('/internal/payments/void', { body: { orderId } });
    },
  };
}
