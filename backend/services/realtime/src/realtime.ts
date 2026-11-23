import { randomUUID } from 'node:crypto';
import type { Server as HttpServer } from 'node:http';
import { ADMIN_ROLES, AppError, type AccessClaims, type AccessTokenVerifier, type Logger } from '@qc/common';
import type { AnyEvent, EventHandler } from '@qc/events';
import { Server, type Socket } from 'socket.io';

/**
 * Socket.IO server for live order updates.
 *
 * Clients connect with `auth: { token: <access JWT> }`. Rooms are always shop-namespaced:
 *   shop:<shopId>:admins          owner + staff of the shop
 *   shop:<shopId>:user:<userId>   one user's phones
 * Events carry only ids and statuses; apps re-fetch details over REST (which enforces access).
 * Sockets are closed when the access token expires (`session.expired`); the app reconnects
 * with a fresh token.
 */

export const adminsRoom = (shopId: string) => `shop:${shopId}:admins`;
export const userRoom = (shopId: string, userId: string) => `shop:${shopId}:user:${userId}`;

export interface OrderUpdate {
  orderId: string;
  number: number;
  status: string;
}

export interface DeliveryUpdate {
  orderId: string;
  status: 'ASSIGNED' | 'PICKED_UP' | 'DELIVERED' | 'CANCELLED';
  /** false for the rider who just lost the delivery to a reassignment. */
  mine?: boolean;
}

export interface RiderLocationUpdate {
  orderId: string;
  lat: number;
  lng: number;
  accuracy: number | null;
  at: string;
}

export interface LocationPing {
  lat: number;
  lng: number;
  accuracy: number | null;
}

/** Delivery service: stores a rider's location (only while on the way) and says who may see it. */
export type ReportLocation = (
  identity: { requestId: string; shopId: string; userId: string; role: 'RIDER' },
  ping: LocationPing,
) => Promise<{ targets: { orderId: string; customerId: string }[]; location: { lat: number; lng: number; accuracy: number | null; at: string } | null }>;

export interface PaymentUpdate {
  orderId: string;
  status: 'SUBMITTED' | 'PAID';
}

type ServerEvents = {
  'order.updated': (update: OrderUpdate) => void;
  'payment.updated': (update: PaymentUpdate) => void;
  'delivery.updated': (update: DeliveryUpdate) => void;
  'rider.location': (update: RiderLocationUpdate) => void;
  'session.expired': () => void;
};

type ClientEvents = {
  /** Rider app, every ~10 s while delivering. Ack tells it how many orders are being tracked. */
  'rider.location': (ping: unknown, ack?: (result: { ok: boolean; tracking: number }) => void) => void;
};

/** Minimum gap between accepted location pings per socket. */
export const LOCATION_MIN_INTERVAL_MS = 4000;

export interface RealtimeOptions {
  verify: AccessTokenVerifier;
  logger: Logger;
  reportLocation?: ReportLocation;
  now?: () => number;
}

function parsePing(raw: unknown): LocationPing | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const { lat, lng, accuracy } = raw as Record<string, unknown>;
  if (typeof lat !== 'number' || typeof lng !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  return { lat, lng, accuracy: typeof accuracy === 'number' && accuracy >= 0 && accuracy <= 10_000 ? accuracy : null };
}

export function attachRealtime(httpServer: HttpServer, { verify, logger, reportLocation, now = Date.now }: RealtimeOptions) {
  const io = new Server<ClientEvents, ServerEvents, Record<string, never>, { claims: AccessClaims }>(httpServer, {
    path: '/socket.io',
    serveClient: false,
    // Mobile apps send no Origin; browsers are not a client of this service.
    cors: { origin: false },
    pingInterval: 25_000,
    pingTimeout: 20_000,
  });

  io.use(async (socket, next) => {
    const token = (socket.handshake.auth as { token?: unknown } | undefined)?.token;
    if (typeof token !== 'string' || token.length === 0) return next(new Error('TOKEN_MISSING'));
    try {
      socket.data.claims = await verify(token);
      next();
    } catch (err) {
      next(new Error(err instanceof AppError ? err.code : 'TOKEN_INVALID'));
    }
  });

  io.on('connection', (socket: Socket<ClientEvents, ServerEvents, Record<string, never>, { claims: AccessClaims }>) => {
    const { shopId, userId, role, expiresAt } = socket.data.claims;
    void socket.join(userRoom(shopId, userId));
    if (ADMIN_ROLES.includes(role)) void socket.join(adminsRoom(shopId));

    const msLeft = expiresAt * 1000 - now();
    const timer = setTimeout(() => {
      socket.emit('session.expired');
      socket.disconnect(true);
    }, Math.max(msLeft, 0));
    socket.on('disconnect', () => clearTimeout(timer));

    let lastPing = 0;
    socket.on('rider.location', (raw, ack) => {
      const reply = typeof ack === 'function' ? ack : () => {};
      const ping = parsePing(raw);
      if (role !== 'RIDER' || !reportLocation || !ping || now() - lastPing < LOCATION_MIN_INTERVAL_MS) {
        return reply({ ok: false, tracking: 0 });
      }
      lastPing = now();
      reportLocation({ requestId: randomUUID(), shopId, userId, role: 'RIDER' }, ping).then(
        ({ targets, location }) => {
          if (location) {
            for (const target of targets) {
              io.to([userRoom(shopId, target.customerId), adminsRoom(shopId)]).emit('rider.location', { orderId: target.orderId, ...location });
            }
          }
          reply({ ok: true, tracking: targets.length });
        },
        (err: unknown) => {
          logger.warn({ err, shopId, userId }, 'rider location not stored');
          reply({ ok: false, tracking: 0 });
        },
      );
    });
    logger.debug({ shopId, userId, role }, 'socket connected');
  });

  /** Domain event → the rooms that may know about it. */
  const handle: EventHandler = async (event: AnyEvent) => {
    const shopId = event.shopId;
    switch (event.type) {
      case 'order.placed':
      case 'order.status_changed': {
        const p = event.payload;
        const update: OrderUpdate = { orderId: p.orderId, number: p.number, status: 'to' in p ? p.to : 'PLACED' };
        io.to([adminsRoom(shopId), userRoom(shopId, p.customerId)]).emit('order.updated', update);
        break;
      }
      case 'payment.utr_submitted':
      case 'payment.marked_paid': {
        const p = event.payload;
        const update: PaymentUpdate = { orderId: p.orderId, status: event.type === 'payment.marked_paid' ? 'PAID' : 'SUBMITTED' };
        io.to([adminsRoom(shopId), userRoom(shopId, p.customerId)]).emit('payment.updated', update);
        break;
      }
      case 'delivery.status_changed': {
        const p = event.payload;
        io.to([adminsRoom(shopId), userRoom(shopId, p.customerId), userRoom(shopId, p.riderId)]).emit('delivery.updated', {
          orderId: p.orderId,
          status: p.status,
        });
        if (p.previousRiderId) {
          io.to(userRoom(shopId, p.previousRiderId)).emit('delivery.updated', { orderId: p.orderId, status: p.status, mine: false });
        }
        break;
      }
    }
  };

  return { io, handle };
}

export const REALTIME_EVENTS = [
  'order.placed',
  'order.status_changed',
  'payment.utr_submitted',
  'payment.marked_paid',
  'delivery.status_changed',
] as const;
