import { uuidv7 } from '@qc/common';
import { z } from 'zod';

/**
 * Domain event catalog. Every event travels in the same envelope:
 *   { eventId, type, version, shopId, occurredAt, payload }
 * `stream` is the Redis stream it is published on (`qc:events:<stream>`).
 *
 * Changing a payload in a breaking way means adding a new version, never editing one in place:
 * consumers of the old shape may still be running during a deploy.
 */

const ORDER_STATUSES = [
  'PLACED',
  'CONFIRMED',
  'PACKED',
  'OUT_FOR_DELIVERY',
  'READY_FOR_PICKUP',
  'DELIVERED',
  'PICKED_UP',
  'CANCELLED',
  'REJECTED',
] as const;

const uuid = z.uuid();
const paise = z.number().int().nonnegative();

export const EVENTS = {
  'order.placed': {
    stream: 'order',
    version: 1,
    payload: z.object({
      orderId: uuid,
      number: z.number().int().positive(),
      customerId: uuid,
      totalPaise: paise,
      /** 0 for a list order (photo of a list / prescription; the shop prices it when accepting). */
      itemCount: z.number().int().nonnegative(),
      fulfillment: z.enum(['DELIVERY', 'PICKUP']),
      paymentMethod: z.enum(['COD', 'UPI']),
      needsPricing: z.boolean().optional(),
      /** Chosen delivery window start (ISO), when slots are on. */
      slotStart: z.iso.datetime().nullable().optional(),
      /** Order lines (reporting: top products). Optional: older events have none. */
      items: z
        .array(
          z.object({
            productId: uuid,
            variantId: uuid,
            productName: z.string(),
            variantLabel: z.string(),
            qty: z.number().int().positive(),
            lineTotalPaise: paise,
          }),
        )
        .optional(),
    }),
  },
  'order.status_changed': {
    stream: 'order',
    version: 1,
    payload: z.object({
      orderId: uuid,
      number: z.number().int().positive(),
      customerId: uuid,
      fulfillment: z.enum(['DELIVERY', 'PICKUP']),
      from: z.enum(ORDER_STATUSES),
      to: z.enum(ORDER_STATUSES),
      byRole: z.string().nullable(),
      reason: z.string().nullable(),
      /** List orders: the amount the shop set when accepting. */
      pricedTotalPaise: paise.optional(),
    }),
  },
  'return.requested': {
    stream: 'order',
    version: 1,
    payload: z.object({
      returnId: uuid,
      orderId: uuid,
      number: z.number().int().positive(),
      customerId: uuid,
      type: z.enum(['RETURN', 'EXCHANGE']),
    }),
  },
  'return.status_changed': {
    stream: 'order',
    version: 1,
    payload: z.object({
      returnId: uuid,
      orderId: uuid,
      number: z.number().int().positive(),
      customerId: uuid,
      type: z.enum(['RETURN', 'EXCHANGE']),
      status: z.enum(['APPROVED', 'REJECTED', 'COMPLETED']),
      note: z.string().nullable(),
    }),
  },
  'payment.utr_submitted': {
    stream: 'payment',
    version: 1,
    payload: z.object({ orderId: uuid, orderNumber: z.number().int().positive(), customerId: uuid, amountPaise: paise }),
  },
  'payment.marked_paid': {
    stream: 'payment',
    version: 1,
    payload: z.object({ orderId: uuid, orderNumber: z.number().int().positive(), customerId: uuid, amountPaise: paise }),
  },
  'delivery.status_changed': {
    stream: 'delivery',
    version: 1,
    payload: z.object({
      deliveryId: uuid,
      orderId: uuid,
      number: z.number().int().positive(),
      customerId: uuid,
      riderId: uuid,
      /** Set on a reassignment: the rider who no longer has this delivery. */
      previousRiderId: uuid.nullable(),
      status: z.enum(['ASSIGNED', 'PICKED_UP', 'DELIVERED', 'CANCELLED']),
    }),
  },
} as const;

export type EventType = keyof typeof EVENTS;
export type EventPayload<T extends EventType> = z.infer<(typeof EVENTS)[T]['payload']>;
export type StreamName = (typeof EVENTS)[EventType]['stream'];
export const STREAMS = [...new Set(Object.values(EVENTS).map((e) => e.stream))] as StreamName[];

export interface DomainEvent<T extends EventType = EventType> {
  eventId: string;
  type: T;
  version: number;
  shopId: string;
  occurredAt: string;
  payload: EventPayload<T>;
}

/** Any event of the catalog, narrowed by `type`. */
export type AnyEvent = { [T in EventType]: DomainEvent<T> }[EventType];

export const streamKey = (stream: StreamName | string) => `qc:events:${stream}`;
export const DEAD_LETTER_STREAM = 'qc:events:dead';

const envelopeSchema = z.object({
  eventId: uuid,
  type: z.string(),
  version: z.number().int().positive(),
  shopId: uuid,
  occurredAt: z.iso.datetime(),
  payload: z.unknown(),
});

/** Builds and validates an event. Throws if the payload does not match the catalog. */
export function buildEvent<T extends EventType>(
  type: T,
  shopId: string,
  payload: EventPayload<T>,
  options: { eventId?: string; now?: Date } = {},
): DomainEvent<T> {
  const spec = EVENTS[type];
  return {
    eventId: options.eventId ?? uuidv7(),
    type,
    version: spec.version,
    shopId,
    occurredAt: (options.now ?? new Date()).toISOString(),
    payload: spec.payload.parse(payload) as EventPayload<T>,
  };
}

export type ParseResult = { ok: true; event: AnyEvent } | { ok: false; reason: string };

/** Parses a published envelope. Unknown types or versions are reported, not thrown: consumers skip them. */
export function parseEvent(raw: string): ParseResult {
  let json: unknown;
  try {
    json = JSON.parse(raw);
  } catch {
    return { ok: false, reason: 'invalid JSON' };
  }
  const envelope = envelopeSchema.safeParse(json);
  if (!envelope.success) return { ok: false, reason: 'invalid envelope' };
  const spec = (EVENTS as Record<string, (typeof EVENTS)[EventType]>)[envelope.data.type];
  if (!spec) return { ok: false, reason: `unknown type ${envelope.data.type}` };
  if (spec.version !== envelope.data.version) {
    return { ok: false, reason: `unsupported version ${envelope.data.type}@${envelope.data.version}` };
  }
  const payload = spec.payload.safeParse(envelope.data.payload);
  if (!payload.success) return { ok: false, reason: `invalid payload for ${envelope.data.type}` };
  return { ok: true, event: { ...envelope.data, payload: payload.data } as AnyEvent };
}

/** Row written to a service's `outbox_events` table in the same transaction as the change. */
export function toOutboxRow(event: DomainEvent) {
  return {
    id: event.eventId,
    shopId: event.shopId,
    type: event.type,
    stream: EVENTS[event.type].stream,
    envelope: event as unknown as Record<string, unknown>,
  };
}
