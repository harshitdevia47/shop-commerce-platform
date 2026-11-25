import type { Logger, ShopConfigSource } from '@qc/common';
import type { RuntimeConfig } from '@qc/config-schema';
import type { AnyEvent, EventHandler } from '@qc/events';
import { defaultNote, defaultReason, fill, formatRupees, messagesFor, type CustomerStatus } from './messages.js';
import type { PushMessage, PushSender } from '@qc/fcm';

export interface PushTarget {
  userId: string;
  token: string;
  platform: string;
  locale: string;
}

/** Identity's device registry (POST /internal/devices/targets and /remove). */
export interface DeviceDirectory {
  targets(query: { userIds?: string[]; admins?: boolean }): Promise<PushTarget[]>;
  remove(tokens: string[]): Promise<void>;
}

export const ANDROID_CHANNEL = 'orders';

const CUSTOMER_STATUSES: readonly string[] = [
  'CONFIRMED',
  'PACKED',
  'OUT_FOR_DELIVERY',
  'READY_FOR_PICKUP',
  'DELIVERED',
  'PICKED_UP',
  'REJECTED',
] satisfies CustomerStatus[];

type Audience = { userIds: string[] } | { admins: true };

interface Plan {
  audience: Audience;
  route: string;
  orderId: string;
  /** Text per phone language. */
  text(locale: string, shopName: string): { title: string; body: string };
}

/** Who hears about an event and what they read. Empty = nobody. */
export function plansFor(event: AnyEvent): Plan[] {
  if (event.type === 'delivery.status_changed') {
    const p = event.payload;
    const plans: Plan[] = [];
    const route = `/rider/deliveries/${p.deliveryId}`;
    if (p.status === 'ASSIGNED') {
      plans.push({ audience: { userIds: [p.riderId] }, route, orderId: p.orderId, text: (l) => fill(messagesFor(l).riderAssigned, { n: p.number }) });
      if (p.previousRiderId) {
        plans.push({
          audience: { userIds: [p.previousRiderId] },
          route: '/rider',
          orderId: p.orderId,
          text: (l) => fill(messagesFor(l).riderReassigned, { n: p.number }),
        });
      }
    } else if (p.status === 'CANCELLED') {
      plans.push({ audience: { userIds: [p.riderId] }, route, orderId: p.orderId, text: (l) => fill(messagesFor(l).riderCancelled, { n: p.number }) });
    }
    // PICKED_UP / DELIVERED: the customer already hears it through order.status_changed.
    return plans;
  }
  const plan = planFor(event);
  return plan ? [plan] : [];
}

function planFor(event: Exclude<AnyEvent, { type: 'delivery.status_changed' }>): Plan | null {
  switch (event.type) {
    case 'order.placed': {
      const p = event.payload;
      return {
        audience: { admins: true },
        route: `/admin/orders/${p.orderId}`,
        orderId: p.orderId,
        text: (locale) => {
          const m = messagesFor(locale);
          if (p.needsPricing) {
            return fill(m.newListOrder, {
              n: p.number,
              fulfillment: p.fulfillment === 'DELIVERY' ? m.delivery : m.pickup,
              payment: p.paymentMethod === 'RAZORPAY' ? m.online : p.paymentMethod,
            });
          }
          return fill(m.newOrder, {
            n: p.number,
            amount: formatRupees(p.totalPaise),
            items: m.items.replace('{count}', String(p.itemCount)),
            fulfillment: p.fulfillment === 'DELIVERY' ? m.delivery : m.pickup,
            payment: p.paymentMethod === 'RAZORPAY' ? m.online : p.paymentMethod,
          });
        },
      };
    }
    case 'order.status_changed': {
      const p = event.payload;
      if (p.to === 'CANCELLED') {
        // Customers cancel their own orders: tell the shop.
        return {
          audience: { admins: true },
          route: `/admin/orders/${p.orderId}`,
          orderId: p.orderId,
          text: (locale) => fill(messagesFor(locale).cancelledByCustomer, { n: p.number }),
        };
      }
      if (!CUSTOMER_STATUSES.includes(p.to)) return null;
      return {
        audience: { userIds: [p.customerId] },
        route: `/orders/${p.orderId}`,
        orderId: p.orderId,
        text: (locale, shop) =>
          fill(messagesFor(locale).status[p.to as CustomerStatus], {
            n: p.number,
            shop,
            reason: p.reason ?? defaultReason(locale),
          }),
      };
    }
    case 'return.requested': {
      const p = event.payload;
      return {
        audience: { admins: true },
        route: `/admin/orders/${p.orderId}`,
        orderId: p.orderId,
        text: (locale) => fill(p.type === 'EXCHANGE' ? messagesFor(locale).exchangeRequested : messagesFor(locale).returnRequested, { n: p.number }),
      };
    }
    case 'return.status_changed': {
      const p = event.payload;
      return {
        audience: { userIds: [p.customerId] },
        route: `/orders/${p.orderId}`,
        orderId: p.orderId,
        text: (locale, shop) => fill(messagesFor(locale).returnStatus[p.status], { n: p.number, shop, note: p.note ?? defaultNote(locale) }),
      };
    }
    case 'payment.utr_submitted': {
      const p = event.payload;
      return {
        audience: { admins: true },
        route: `/admin/orders/${p.orderId}`,
        orderId: p.orderId,
        text: (locale) => fill(messagesFor(locale).utrSubmitted, { n: p.orderNumber, amount: formatRupees(p.amountPaise) }),
      };
    }
    case 'payment.marked_paid': {
      const p = event.payload;
      return {
        audience: { userIds: [p.customerId] },
        route: `/orders/${p.orderId}`,
        orderId: p.orderId,
        text: (locale, shop) => fill(messagesFor(locale).markedPaid, { n: p.orderNumber, shop, amount: formatRupees(p.amountPaise) }),
      };
    }
  }
}

export const NOTIFIED_EVENTS = [
  'order.placed',
  'order.status_changed',
  'payment.utr_submitted',
  'payment.marked_paid',
  'delivery.status_changed',
  'return.requested',
  'return.status_changed',
] as const;

export interface NotifierDeps {
  shopConfig: ShopConfigSource<RuntimeConfig>;
  devices: DeviceDirectory;
  push: PushSender;
  logger: Logger;
}

/** Event handler: finds the phones to notify, writes each push in that phone's language, sends. */
export function createNotifier({ shopConfig, devices, push, logger }: NotifierDeps): EventHandler {
  return async (event) => {
    const plans = plansFor(event);
    if (plans.length === 0) return;
    const { shop } = await shopConfig.get();
    const messages: PushMessage[] = [];
    for (const plan of plans) {
      const targets = await devices.targets(plan.audience);
      for (const t of targets) {
        messages.push({
          token: t.token,
          ...plan.text(t.locale, shop.nameI18n?.[t.locale as keyof typeof shop.nameI18n] ?? shop.name),
          data: { type: event.type, orderId: plan.orderId, route: plan.route },
          channelId: ANDROID_CHANNEL,
          tag: plan.orderId,
        });
      }
    }
    if (messages.length === 0) return;
    const result = await push.send(messages);
    if (result.invalidTokens.length > 0) await devices.remove(result.invalidTokens);
    logger.info({ eventId: event.eventId, type: event.type, sent: result.sent, invalid: result.invalidTokens.length }, 'push sent');
  };
}
