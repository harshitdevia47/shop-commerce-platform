import type { Logger, ShopConfigSource } from '@qc/common';
import type { RuntimeConfig } from '@qc/config-schema';
import type { AnyEvent, EventHandler } from '@qc/events';
import { defaultReason, fill, formatRupees, messagesFor, type CustomerStatus } from './messages.js';
import type { PushMessage, PushSender } from './push/push-sender.js';

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

/** Who hears about an event and what they read. Null = nobody. */
export function planFor(event: AnyEvent): Plan | null {
  switch (event.type) {
    case 'order.placed': {
      const p = event.payload;
      return {
        audience: { admins: true },
        route: `/admin/orders/${p.orderId}`,
        orderId: p.orderId,
        text: (locale) => {
          const m = messagesFor(locale);
          return fill(m.newOrder, {
            n: p.number,
            amount: formatRupees(p.totalPaise),
            items: m.items.replace('{count}', String(p.itemCount)),
            fulfillment: p.fulfillment === 'DELIVERY' ? m.delivery : m.pickup,
            payment: p.paymentMethod,
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

export const NOTIFIED_EVENTS = ['order.placed', 'order.status_changed', 'payment.utr_submitted', 'payment.marked_paid'] as const;

export interface NotifierDeps {
  shopConfig: ShopConfigSource<RuntimeConfig>;
  devices: DeviceDirectory;
  push: PushSender;
  logger: Logger;
}

/** Event handler: finds the phones to notify, writes each push in that phone's language, sends. */
export function createNotifier({ shopConfig, devices, push, logger }: NotifierDeps): EventHandler {
  return async (event) => {
    const plan = planFor(event);
    if (!plan) return;
    const targets = await devices.targets(plan.audience);
    if (targets.length === 0) return;

    const { shop } = await shopConfig.get();
    const messages: PushMessage[] = targets.map((t) => ({
      token: t.token,
      ...plan.text(t.locale, shop.nameI18n?.[t.locale as keyof typeof shop.nameI18n] ?? shop.name),
      data: { type: event.type, orderId: plan.orderId, route: plan.route },
      channelId: ANDROID_CHANNEL,
      tag: plan.orderId,
    }));
    const result = await push.send(messages);
    if (result.invalidTokens.length > 0) await devices.remove(result.invalidTokens);
    logger.info({ eventId: event.eventId, type: event.type, sent: result.sent, invalid: result.invalidTokens.length }, 'push sent');
  };
}
