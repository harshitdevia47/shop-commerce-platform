import type { EventHandler } from '@qc/events';
import type { DeliveriesService } from '../modules/deliveries/deliveries.service.js';

/** Order changed (by the shop, the customer, or the rider flow itself): keep the delivery in step. */
export function orderEventsHandler(deliveries: DeliveriesService): EventHandler {
  return async (event) => {
    if (event.type === 'order.status_changed') await deliveries.onOrderStatus(event.payload.orderId, event.payload.to);
  };
}
