import {
  AppError,
  Errors,
  getContext,
  requireShopId,
  toPage,
  uuidv7,
  type Logger,
  type Page,
  type ShopConfigSource,
} from '@qc/common';
import type { RuntimeConfig } from '@qc/config-schema';
import { buildEvent, toOutboxRow } from '@qc/events';
import type { Db } from '../../db.js';
import { Prisma, type Fulfillment, type OrderStatus, type PaymentMethod } from '../../generated/prisma/client.js';
import type { CatalogPort, CheckoutAddress, IdentityPort, PaymentPort, PaymentView } from '../../upstreams.js';
import { haversineKm, mergeLines, priceCart, type CartLine, type Quote } from './pricing.js';
import { DONE, TERMINAL_FAILED, canTransition, nextStatuses } from './status.js';

export interface PlaceOrderInput {
  items: CartLine[];
  fulfillment: Fulfillment;
  addressId?: string;
  paymentMethod: PaymentMethod;
  note?: string;
  idempotencyKey: string;
  /** Total the customer saw; if prices changed since, the order is refused with the new quote. */
  expectedTotalPaise?: number;
}

export interface OrderQuery {
  cursor?: string;
  limit: number;
  /** Admin filters. */
  status?: OrderStatus;
  group?: 'new' | 'active' | 'done';
}

const withDetails = {
  items: { orderBy: { id: 'asc' } },
  history: { orderBy: { createdAt: 'asc' } },
} satisfies Prisma.OrderInclude;

type OrderRow = Prisma.OrderGetPayload<{ include: typeof withDetails }>;
type I18n = Record<string, string> | null;

/** The same shape for customer and admin; `nextStatuses` depends on who asks. */
export function toOrderView(order: OrderRow) {
  const role = getContext()?.role;
  return {
    id: order.id,
    number: order.number,
    status: order.status,
    fulfillment: order.fulfillment,
    address: order.address as CheckoutAddress | null,
    note: order.note,
    paymentMethod: order.paymentMethod,
    customer: { id: order.customerId, phone: order.customerPhone, name: order.customerName },
    items: order.items.map((i) => ({
      productId: i.productId,
      variantId: i.variantId,
      productName: i.productName,
      productNameI18n: (i.productNameI18n as I18n) ?? null,
      variantLabel: i.variantLabel,
      variantLabelI18n: (i.variantLabelI18n as I18n) ?? null,
      thumbUrl: i.thumbUrl,
      pricePaise: i.pricePaise,
      mrpPaise: i.mrpPaise,
      qty: i.qty,
      lineTotalPaise: i.lineTotalPaise,
    })),
    itemCount: order.itemCount,
    subtotalPaise: order.subtotalPaise,
    deliveryFeePaise: order.deliveryFeePaise,
    totalPaise: order.totalPaise,
    cancelReason: order.cancelReason,
    placedAt: order.placedAt,
    updatedAt: order.updatedAt,
    history: order.history.map((h) => ({ status: h.to, at: h.createdAt, byRole: h.byRole, reason: h.reason })),
    nextStatuses: nextStatuses(order.status, order.fulfillment, role),
  };
}

export type OrderView = ReturnType<typeof toOrderView>;

export interface OrdersServiceDeps {
  db: Db;
  logger: Logger;
  shopConfig: ShopConfigSource<RuntimeConfig>;
  catalog: CatalogPort;
  identity: IdentityPort;
  payments: PaymentPort;
  /** Outbox relay: told to publish right after a transaction that wrote events commits. */
  events?: { kick(): void };
}

export function createOrdersService({ db, logger, shopConfig, catalog, identity, payments, events }: OrdersServiceDeps) {
  const userId = () => getContext()!.userId!;

  async function quote(items: CartLine[], fulfillment: Fulfillment): Promise<Quote> {
    const config = await shopConfig.get();
    checkFulfillment(config, fulfillment);
    const lines = mergeLines(items);
    const snapshots = await catalog.lookup(lines.map((l) => l.variantId));
    return priceCart(lines, snapshots, config.delivery, fulfillment);
  }

  function checkFulfillment(config: RuntimeConfig, fulfillment: Fulfillment): void {
    if (fulfillment === 'DELIVERY' && !config.delivery.enabled) {
      throw Errors.badRequest('DELIVERY_UNAVAILABLE', 'This shop does not deliver; choose store pickup');
    }
    if (fulfillment === 'PICKUP' && !config.features.storePickup) {
      throw Errors.badRequest('PICKUP_UNAVAILABLE', 'This shop does not offer store pickup');
    }
  }

  function checkDeliveryArea(config: RuntimeConfig, address: CheckoutAddress): void {
    const { pincodes, radiusKm } = config.delivery;
    if (pincodes.length > 0 && !pincodes.includes(address.pincode)) {
      throw Errors.badRequest('OUTSIDE_DELIVERY_AREA', 'The shop does not deliver to this pincode');
    }
    if (address.lat !== null && address.lng !== null) {
      const km = haversineKm(config.shop.contact, { lat: address.lat, lng: address.lng });
      if (km > radiusKm) throw Errors.badRequest('OUTSIDE_DELIVERY_AREA', 'This address is outside the delivery area');
    }
  }

  async function find(id: string, ownOnly: boolean): Promise<OrderRow> {
    const order = await db.order.findFirst({
      where: { id, ...(ownOnly ? { customerId: userId() } : {}) },
      include: withDetails,
    });
    if (!order) throw Errors.notFound('ORDER_NOT_FOUND', 'Order not found');
    return order;
  }

  async function existingFor(idempotencyKey: string): Promise<OrderRow | null> {
    return db.order.findFirst({ where: { customerId: userId(), idempotencyKey }, include: withDetails });
  }

  /**
   * Best effort compensation (fast path). Durable fallbacks: catalog and payment consume
   * `order.status_changed`, and their sweepers release/void anything held for an order
   * that was never created (`POST /internal/orders/existing`).
   */
  async function compensate(orderId: string, steps: { release?: boolean; void?: boolean }): Promise<void> {
    const results = await Promise.allSettled([
      steps.release ? catalog.release(orderId) : Promise.resolve(),
      steps.void ? payments.void(orderId) : Promise.resolve(),
    ]);
    for (const result of results) {
      if (result.status === 'rejected') logger.error({ err: result.reason, orderId }, 'order compensation failed');
    }
  }

  async function nextNumber(): Promise<number> {
    const shopId = requireShopId();
    const counter = await db.orderCounter.upsert({
      where: { shopId },
      create: { shopId, lastNumber: 1 },
      update: { lastNumber: { increment: 1 } },
    });
    return counter.lastNumber;
  }

  async function changeStatus(order: OrderRow, to: OrderStatus, reason?: string): Promise<OrderRow> {
    const context = getContext()!;
    if (!canTransition(order.status, to, order.fulfillment, context.role)) {
      throw Errors.conflict('ORDER_STATUS_INVALID', `Cannot change an order from ${order.status} to ${to}`);
    }
    await db.$transaction(async (tx) => {
      // Conditional on the status we read: two staff tapping at once cannot both win.
      const updated = await tx.order.updateMany({
        where: { id: order.id, status: order.status },
        data: { status: to, ...(TERMINAL_FAILED.includes(to) ? { cancelReason: reason ?? null } : {}) },
      });
      if (updated.count === 0) throw Errors.conflict('ORDER_STATUS_CHANGED', 'The order was updated by someone else');
      await tx.orderStatusChange.create({
        data: {
          shopId: requireShopId(),
          orderId: order.id,
          from: order.status,
          to,
          byUserId: context.userId ?? null,
          byRole: context.role ?? null,
          reason: reason ?? null,
        },
      });
      // Catalog and payment also react to this event (release stock, void payment), so the
      // compensation below is only the fast path; the event makes it durable.
      const event = buildEvent('order.status_changed', requireShopId(), {
        orderId: order.id,
        number: order.number,
        customerId: order.customerId,
        fulfillment: order.fulfillment,
        from: order.status,
        to,
        byRole: context.role ?? null,
        reason: reason ?? null,
      });
      await tx.outboxEvent.create({ data: toOutboxRow(event) as Prisma.OutboxEventUncheckedCreateInput });
    });
    events?.kick();
    if (TERMINAL_FAILED.includes(to)) await compensate(order.id, { release: true, void: true });
    return find(order.id, false);
  }

  return {
    quote,

    /**
     * Place-order saga:
     *   price from catalog → reserve stock → number → payment record → order row.
     * Each step after reserve compensates the earlier ones on failure.
     */
    async place(input: PlaceOrderInput): Promise<{ order: OrderView; payment: PaymentView | null }> {
      const existing = await existingFor(input.idempotencyKey);
      if (existing) return { order: toOrderView(existing), payment: null };

      const config = await shopConfig.get();
      checkFulfillment(config, input.fulfillment);
      if (input.note && !config.features.orderNotes) {
        throw Errors.badRequest('FEATURE_DISABLED', 'This shop does not take order notes');
      }
      if (input.fulfillment === 'DELIVERY' && !input.addressId) {
        throw Errors.badRequest('ADDRESS_REQUIRED', 'Choose a delivery address');
      }

      const profile = await identity.checkoutProfile(userId(), input.fulfillment === 'DELIVERY' ? input.addressId : undefined);
      if (profile.user.isBlocked) throw Errors.forbidden('USER_BLOCKED', 'This account is blocked');
      if (profile.address) checkDeliveryArea(config, profile.address);

      const priced = await quote(input.items, input.fulfillment);
      if (priced.missing.length > 0 || priced.lines.some((l) => l.issue)) {
        throw new AppError('CART_CHANGED', 409, 'Some items are no longer available', { quote: priced });
      }
      if (priced.subtotalPaise < priced.minOrderPaise) {
        throw new AppError('BELOW_MINIMUM_ORDER', 400, 'Add more items to reach the minimum order', {
          minOrderPaise: priced.minOrderPaise,
        });
      }
      if (input.expectedTotalPaise !== undefined && input.expectedTotalPaise !== priced.totalPaise) {
        throw new AppError('PRICE_CHANGED', 409, 'Prices changed; please review your cart', { quote: priced });
      }

      const orderId = uuidv7();
      await catalog.reserve(orderId, priced.lines.map((l) => ({ variantId: l.variantId, qty: l.qty })));

      let payment: PaymentView;
      let number: number;
      try {
        number = await nextNumber();
        payment = await payments.create({
          orderId,
          orderNumber: number,
          customerId: userId(),
          method: input.paymentMethod,
          amountPaise: priced.totalPaise,
        });
      } catch (err) {
        await compensate(orderId, { release: true });
        throw err;
      }

      try {
        await db.$transaction(async (tx) => {
          const shopId = requireShopId();
          await tx.order.create({
            data: {
              id: orderId,
              shopId,
              number,
              customerId: userId(),
              customerPhone: profile.user.phone,
              customerName: profile.user.name,
              fulfillment: input.fulfillment,
              address: profile.address ? (profile.address as unknown as Prisma.InputJsonValue) : Prisma.DbNull,
              note: input.note ?? null,
              paymentMethod: input.paymentMethod,
              subtotalPaise: priced.subtotalPaise,
              deliveryFeePaise: priced.deliveryFeePaise,
              totalPaise: priced.totalPaise,
              itemCount: priced.itemCount,
              idempotencyKey: input.idempotencyKey,
            },
          });
          await tx.orderItem.createMany({
            data: priced.lines.map((l) => ({
              shopId,
              orderId,
              productId: l.productId,
              variantId: l.variantId,
              productName: l.productName,
              productNameI18n: (l.productNameI18n ?? Prisma.DbNull) as Prisma.InputJsonValue,
              variantLabel: l.label,
              variantLabelI18n: (l.labelI18n ?? Prisma.DbNull) as Prisma.InputJsonValue,
              thumbUrl: l.thumbUrl,
              pricePaise: l.pricePaise,
              mrpPaise: l.mrpPaise,
              qty: l.qty,
              lineTotalPaise: l.lineTotalPaise,
            })),
          });
          await tx.orderStatusChange.create({
            data: { shopId, orderId, from: null, to: 'PLACED', byUserId: userId(), byRole: getContext()!.role ?? null },
          });
          const event = buildEvent('order.placed', shopId, {
            orderId,
            number,
            customerId: userId(),
            totalPaise: priced.totalPaise,
            itemCount: priced.itemCount,
            fulfillment: input.fulfillment,
            paymentMethod: input.paymentMethod,
          });
          await tx.outboxEvent.create({ data: toOutboxRow(event) as Prisma.OutboxEventUncheckedCreateInput });
        });
        events?.kick();
      } catch (err) {
        await compensate(orderId, { release: true, void: true });
        // Double tap: the other request with the same key created the order.
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          const winner = await existingFor(input.idempotencyKey);
          if (winner) return { order: toOrderView(winner), payment: null };
        }
        throw err;
      }

      logger.info({ orderId, number, totalPaise: priced.totalPaise }, 'order placed');
      return { order: toOrderView(await find(orderId, false)), payment };
    },

    async listMine(query: OrderQuery): Promise<Page<OrderView>> {
      const rows = await db.order.findMany({
        where: { customerId: userId() },
        include: withDetails,
        orderBy: { id: 'desc' },
        take: query.limit + 1,
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
      });
      return toPage(rows, query.limit, (o) => o.id, toOrderView);
    },

    async listForShop(query: OrderQuery): Promise<Page<OrderView>> {
      const where: Prisma.OrderWhereInput = {};
      if (query.status) where.status = query.status;
      else if (query.group === 'new') where.status = 'PLACED';
      else if (query.group === 'active') where.status = { notIn: [...DONE, 'PLACED'] };
      else if (query.group === 'done') where.status = { in: [...DONE] };
      const rows = await db.order.findMany({
        where,
        include: withDetails,
        orderBy: { id: query.group === 'done' ? 'desc' : 'asc' }, // open orders: oldest first
        take: query.limit + 1,
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
      });
      return toPage(rows, query.limit, (o) => o.id, toOrderView);
    },

    /** Which of these order ids exist in this shop (used by catalog/payment sweepers). */
    async existing(ids: string[]): Promise<string[]> {
      const rows = await db.order.findMany({ where: { id: { in: ids } }, select: { id: true } });
      return rows.map((r) => r.id);
    },

    getMine: async (id: string) => toOrderView(await find(id, true)),
    getForShop: async (id: string) => toOrderView(await find(id, false)),

    async cancelMine(id: string, reason?: string): Promise<OrderView> {
      const order = await find(id, true);
      if (!canTransition(order.status, 'CANCELLED', order.fulfillment, 'CUSTOMER')) {
        throw Errors.conflict('ORDER_NOT_CANCELLABLE', 'This order can no longer be cancelled; please call the shop');
      }
      return toOrderView(await changeStatus(order, 'CANCELLED', reason));
    },

    async setStatus(id: string, to: OrderStatus, reason?: string): Promise<OrderView> {
      if (to === 'REJECTED' && !reason) throw Errors.badRequest('REASON_REQUIRED', 'Tell the customer why the order was rejected');
      return toOrderView(await changeStatus(await find(id, false), to, reason));
    },
  };
}

export type OrdersService = ReturnType<typeof createOrdersService>;
