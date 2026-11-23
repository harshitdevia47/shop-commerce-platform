import type { Role } from '@qc/common';
import type { Fulfillment, OrderStatus } from '../../generated/prisma/client.js';

/** Who may move an order along an edge. */
type Actor = 'customer' | 'shop';

interface Edge {
  to: OrderStatus;
  by: Actor;
  /** Only for this fulfillment type. */
  only?: Fulfillment;
}

/**
 * The order status machine. Every change goes through here and is written to history.
 *
 *   PLACED → CONFIRMED → PACKED → OUT_FOR_DELIVERY → DELIVERED     (delivery)
 *                              → READY_FOR_PICKUP → PICKED_UP      (pickup)
 *   customer may CANCEL before PACKED; the shop may REJECT until it hands the order over.
 */
export const TRANSITIONS: Record<OrderStatus, readonly Edge[]> = {
  PLACED: [
    { to: 'CONFIRMED', by: 'shop' },
    { to: 'REJECTED', by: 'shop' },
    { to: 'CANCELLED', by: 'customer' },
  ],
  CONFIRMED: [
    { to: 'PACKED', by: 'shop' },
    { to: 'REJECTED', by: 'shop' },
    { to: 'CANCELLED', by: 'customer' },
  ],
  PACKED: [
    { to: 'OUT_FOR_DELIVERY', by: 'shop', only: 'DELIVERY' },
    { to: 'READY_FOR_PICKUP', by: 'shop', only: 'PICKUP' },
    { to: 'REJECTED', by: 'shop' },
  ],
  OUT_FOR_DELIVERY: [{ to: 'DELIVERED', by: 'shop' }],
  READY_FOR_PICKUP: [
    { to: 'PICKED_UP', by: 'shop' },
    { to: 'REJECTED', by: 'shop' },
  ],
  DELIVERED: [],
  PICKED_UP: [],
  CANCELLED: [],
  REJECTED: [],
};

/** Statuses that give stock back and void an unpaid payment. */
export const TERMINAL_FAILED: readonly OrderStatus[] = ['CANCELLED', 'REJECTED'];
export const DONE: readonly OrderStatus[] = ['DELIVERED', 'PICKED_UP', 'CANCELLED', 'REJECTED'];

const actorOf = (role: Role | undefined): Actor | null =>
  role === 'OWNER' || role === 'STAFF' ? 'shop' : role === 'CUSTOMER' ? 'customer' : null;

/** Next statuses this role may set for an order. */
export function nextStatuses(status: OrderStatus, fulfillment: Fulfillment, role: Role | undefined): OrderStatus[] {
  const actor = actorOf(role);
  return TRANSITIONS[status].filter((e) => e.by === actor && (!e.only || e.only === fulfillment)).map((e) => e.to);
}

export function canTransition(
  from: OrderStatus,
  to: OrderStatus,
  fulfillment: Fulfillment,
  role: Role | undefined,
): boolean {
  return nextStatuses(from, fulfillment, role).includes(to);
}
