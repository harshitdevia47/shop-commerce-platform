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

export interface PaymentUpdate {
  orderId: string;
  status: 'SUBMITTED' | 'PAID';
}

type ServerEvents = {
  'order.updated': (update: OrderUpdate) => void;
  'payment.updated': (update: PaymentUpdate) => void;
  'session.expired': () => void;
};

export interface RealtimeOptions {
  verify: AccessTokenVerifier;
  logger: Logger;
  now?: () => number;
}

export function attachRealtime(httpServer: HttpServer, { verify, logger, now = Date.now }: RealtimeOptions) {
  const io = new Server<Record<string, never>, ServerEvents, Record<string, never>, { claims: AccessClaims }>(httpServer, {
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

  io.on('connection', (socket: Socket<Record<string, never>, ServerEvents, Record<string, never>, { claims: AccessClaims }>) => {
    const { shopId, userId, role, expiresAt } = socket.data.claims;
    void socket.join(userRoom(shopId, userId));
    if (ADMIN_ROLES.includes(role)) void socket.join(adminsRoom(shopId));

    const msLeft = expiresAt * 1000 - now();
    const timer = setTimeout(() => {
      socket.emit('session.expired');
      socket.disconnect(true);
    }, Math.max(msLeft, 0));
    socket.on('disconnect', () => clearTimeout(timer));
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
    }
  };

  return { io, handle };
}

export const REALTIME_EVENTS = ['order.placed', 'order.status_changed', 'payment.utr_submitted', 'payment.marked_paid'] as const;
