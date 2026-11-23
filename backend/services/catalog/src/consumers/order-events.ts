import type { EventHandler } from '@qc/events';
import type { StockService } from '../modules/stock/stock.service.js';

/** order.placed commits the reservation; a cancelled/rejected order gives its stock back. */
export function orderEventsHandler(stock: StockService): EventHandler {
  return async (event) => {
    if (event.type === 'order.placed') {
      await stock.commit(event.payload.orderId);
    } else if (event.type === 'order.status_changed' && (event.payload.to === 'CANCELLED' || event.payload.to === 'REJECTED')) {
      await stock.release(event.payload.orderId);
    }
  };
}
