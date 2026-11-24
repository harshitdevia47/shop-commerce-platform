import { requireShopId } from '@qc/common';
import type { EventHandler } from '@qc/events';
import type { Db } from '../db.js';

/** India has no daylight saving: the shop day is the UTC+05:30 calendar day. */
const IST_OFFSET_MS = (5 * 60 + 30) * 60_000;

/** The shop calendar day of an instant, as a UTC-midnight Date (what Postgres `date` columns take). */
export function shopDay(at: Date): Date {
  const shifted = new Date(at.getTime() + IST_OFFSET_MS);
  return new Date(Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()));
}

const COMPLETED = ['DELIVERED', 'PICKED_UP'];

/**
 * Keeps the sales read model in step with order and payment events. Every write is idempotent
 * (create-if-missing, conditional updates), so replaying a stream from the start is safe.
 */
export function salesProjector(db: Db): EventHandler {
  return async (event) => {
    const occurredAt = new Date(event.occurredAt);
    switch (event.type) {
      case 'order.placed': {
        const p = event.payload;
        const shopId = requireShopId();
        const placedDay = shopDay(occurredAt);
        await db.saleOrder.createMany({
          data: [
            {
              shopId,
              orderId: p.orderId,
              number: p.number,
              customerId: p.customerId,
              placedAt: occurredAt,
              placedDay,
              fulfillment: p.fulfillment,
              paymentMethod: p.paymentMethod,
              totalPaise: p.totalPaise,
              itemCount: p.itemCount,
              isListOrder: p.needsPricing ?? false,
              status: 'PLACED',
            },
          ],
          skipDuplicates: true,
        });
        if (p.items?.length) {
          await db.saleItem.createMany({
            data: p.items.map((i) => ({ shopId, orderId: p.orderId, placedDay, ...i })),
            skipDuplicates: true,
          });
        }
        return;
      }
      case 'order.status_changed': {
        const p = event.payload;
        // Orders placed before reporting existed are not in the read model: nothing to update.
        await db.saleOrder.updateMany({
          where: { orderId: p.orderId },
          data: {
            status: p.to,
            ...(COMPLETED.includes(p.to) ? { completedAt: occurredAt } : {}),
            ...(p.pricedTotalPaise !== undefined ? { totalPaise: p.pricedTotalPaise } : {}),
          },
        });
        return;
      }
      case 'payment.marked_paid': {
        await db.salePayment.createMany({
          data: [{ shopId: requireShopId(), orderId: event.payload.orderId, paidAt: occurredAt }],
          skipDuplicates: true,
        });
        return;
      }
      default:
        return;
    }
  };
}

export const PROJECTED_EVENTS = ['order.placed', 'order.status_changed', 'payment.marked_paid'] as const;
