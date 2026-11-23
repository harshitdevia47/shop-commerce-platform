import { runWithContext, uuidv7, type Logger } from '@qc/common';
import type { StockService } from '../modules/stock/stock.service.js';

export interface StaleReservation {
  shopId: string;
  orderId: string;
}

export interface OrderDirectory {
  /** Which of these order ids exist (in the current shop context). */
  existing(ids: string[]): Promise<string[]>;
}

/**
 * Releases stock held by checkouts that failed before the order was created (and whose
 * fast-path compensation also failed). `listStale` returns uncommitted, unreleased
 * reservations older than a few minutes across all shops; each shop's batch is checked
 * against the order service.
 */
export async function sweepOrphanReservations(
  listStale: () => Promise<StaleReservation[]>,
  orders: OrderDirectory,
  stock: StockService,
  logger: Logger,
): Promise<{ committed: number; released: number }> {
  const byShop = new Map<string, Set<string>>();
  for (const { shopId, orderId } of await listStale()) byShop.set(shopId, (byShop.get(shopId) ?? new Set()).add(orderId));

  let committed = 0;
  let released = 0;
  for (const [shopId, orderIds] of byShop) {
    await runWithContext({ requestId: uuidv7(), shopId }, async () => {
      const ids = [...orderIds];
      const existing = new Set(await orders.existing(ids));
      for (const orderId of ids) {
        if (existing.has(orderId)) {
          await stock.commit(orderId);
          committed++;
        } else {
          await stock.release(orderId);
          released++;
          logger.warn({ shopId, orderId }, 'released stock of a checkout that never created an order');
        }
      }
    });
  }
  return { committed, released };
}
