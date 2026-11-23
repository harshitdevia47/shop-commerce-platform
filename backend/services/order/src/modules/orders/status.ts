import type { Role } from '@qc/common';
import type { Fulfillment, OrderStatus } from '../../generated/prisma/client.js';

/** Who may move an order along an edge. */
type Actor = 'customer' | 'shop' | 'rider';

interface Edge {
  to: OrderStatus;
  by: Actor | readonly Actor[];
  /** Only for this fulfillment type. */
  only?: Fulfillment;
}

/**
 * The order status machine. Every change goes through here and is written to history.
 *
 *   PLACED → CONFIRMED → PACKED → OUT_FOR_DELIVERY → DELIVERED     (delivery)
 *                              → READY_FOR_PICKUP → PICKED_UP      (pickup)
 *   customer may CANCEL before PACKED; the shop may REJECT until it hands the order over.
 *   Riders (through the delivery service, which checks the assignment and delivery OTP) take the
 *   order out and deliver it; the shop can do the same itself (own delivery, OTP override).
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
    { to: 'OUT_FOR_DELIVERY', by: ['shop', 'rider'], only: 'DELIVERY' },
    { to: 'READY_FOR_PICKUP', by: 'shop', only: 'PICKUP' },
    { to: 'REJECTED', by: 'shop' },
  ],
  OUT_FOR_DELIVERY: [{ to: 'DELIVERED', by: ['shop', 'rider'] }],
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
  role === 'OWNER' || role === 'STAFF' ? 'shop' : role === 'CUSTOMER' ? 'customer' : role === 'RIDER' ? 'rider' : null;

const allows = (edge: Edge, actor: Actor | null) => actor !== null && (edge.by === actor || (Array.isArray(edge.by) && edge.by.includes(actor)));

/** Next statuses this role may set for an order. */
export function nextStatuses(status: OrderStatus, fulfillment: Fulfillment, role: Role | undefined): OrderStatus[] {
  const actor = actorOf(role);
  return TRANSITIONS[status].filter((e) => allows(e, actor) && (!e.only || e.only === fulfillment)).map((e) => e.to);
}

export function canTransition(
  from: OrderStatus,
  to: OrderStatus,
  fulfillment: Fulfillment,
  role: Role | undefined,
): boolean {
  return nextStatuses(from, fulfillment, role).includes(to);
}
