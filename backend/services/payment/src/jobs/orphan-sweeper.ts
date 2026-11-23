import { runWithContext, uuidv7, type Logger } from '@qc/common';
import type { PaymentsService } from '../modules/payments/payments.service.js';

export interface StalePayment {
  shopId: string;
  orderId: string;
}

export interface OrderDirectory {
  /** Which of these order ids exist (in the current shop context). */
  existing(ids: string[]): Promise<string[]>;
}

/**
 * Voids payments whose checkout failed before the order was created (and whose fast-path
 * compensation also failed). `listStale` returns unconfirmed open payments older than a few
 * minutes across all shops; each shop's batch is checked against the order service.
 */
export async function sweepOrphanPayments(
  listStale: () => Promise<StalePayment[]>,
  orders: OrderDirectory,
  payments: PaymentsService,
  logger: Logger,
): Promise<{ confirmed: number; voided: number }> {
  const byShop = new Map<string, string[]>();
  for (const { shopId, orderId } of await listStale()) byShop.set(shopId, [...(byShop.get(shopId) ?? []), orderId]);

  let confirmed = 0;
  let voided = 0;
  for (const [shopId, orderIds] of byShop) {
    await runWithContext({ requestId: uuidv7(), shopId }, async () => {
      const existing = new Set(await orders.existing(orderIds));
      for (const orderId of orderIds) {
        if (existing.has(orderId)) {
          await payments.confirmOrder(orderId);
          confirmed++;
        } else {
          await payments.void(orderId);
          voided++;
          logger.warn({ shopId, orderId }, 'voided payment of a checkout that never created an order');
        }
      }
    });
  }
  return { confirmed, voided };
}
