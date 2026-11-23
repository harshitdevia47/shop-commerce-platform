import type { EventHandler } from '@qc/events';
import type { PaymentsService } from '../modules/payments/payments.service.js';

/** order.placed confirms the payment; a cancelled/rejected order voids it (unless already paid). */
export function orderEventsHandler(payments: PaymentsService): EventHandler {
  return async (event) => {
    if (event.type === 'order.placed') {
      await payments.confirmOrder(event.payload.orderId);
    } else if (event.type === 'order.status_changed' && (event.payload.to === 'CANCELLED' || event.payload.to === 'REJECTED')) {
      await payments.void(event.payload.orderId);
    }
  };
}
