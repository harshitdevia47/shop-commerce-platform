import type { InternalClient } from '@qc/common';
import type { Redis } from 'ioredis';

export interface OrderAddress {
  label?: string;
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

/** The parts of the order service's order view the delivery flow needs. */
export interface OrderSnapshot {
  id: string;
  number: number;
  status: string;
  fulfillment: 'DELIVERY' | 'PICKUP';
  address: OrderAddress | null;
  note: string | null;
  paymentMethod: 'COD' | 'UPI' | 'RAZORPAY';
  customer: { id: string; phone: string; name: string | null };
  itemCount: number;
  totalPaise: number;
}

export interface Rider {
  id: string;
  name: string | null;
  phone: string;
}

/** Order service, called in the current request's context (a rider's status changes are recorded as RIDER). */
export interface OrderPort {
  get(orderId: string): Promise<OrderSnapshot>;
  setStatus(orderId: string, status: 'OUT_FOR_DELIVERY' | 'DELIVERED'): Promise<OrderSnapshot>;
}

export interface IdentityPort {
  riders(): Promise<Rider[]>;
}

export interface RiderLocation {
  lat: number;
  lng: number;
  /** Metres, as reported by the phone. */
  accuracy: number | null;
  at: string;
}

/** Latest location per rider: short-lived, never stored in Postgres. */
export interface LocationStore {
  set(shopId: string, riderId: string, location: RiderLocation): Promise<void>;
  get(shopId: string, riderId: string): Promise<RiderLocation | null>;
}

export function orderPort(client: InternalClient): OrderPort {
  return {
    get: (orderId) => client.get(`/internal/orders/${orderId}`),
    setStatus: (orderId, status) => client.post(`/internal/orders/${orderId}/status`, { body: { status } }),
  };
}

export function identityPort(client: InternalClient): IdentityPort {
  return { riders: () => client.get('/internal/users/riders') };
}

const LOCATION_TTL_SECONDS = 120;
const locationKey = (shopId: string, riderId: string) => `qc:rider-loc:${shopId}:${riderId}`;

export function redisLocationStore(redis: Redis): LocationStore {
  return {
    async set(shopId, riderId, location) {
      await redis.set(locationKey(shopId, riderId), JSON.stringify(location), 'EX', LOCATION_TTL_SECONDS);
    },
    async get(shopId, riderId) {
      const raw = await redis.get(locationKey(shopId, riderId));
      return raw ? (JSON.parse(raw) as RiderLocation) : null;
    },
  };
}

export function memoryLocationStore(): LocationStore {
  const map = new Map<string, RiderLocation>();
  return {
    set: async (shopId, riderId, location) => void map.set(locationKey(shopId, riderId), location),
    get: async (shopId, riderId) => map.get(locationKey(shopId, riderId)) ?? null,
  };
}
