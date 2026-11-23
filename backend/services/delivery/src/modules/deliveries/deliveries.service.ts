import { randomInt, timingSafeEqual } from 'node:crypto';
import { AppError, Errors, getContext, requireShopId, type Logger } from '@qc/common';
import { buildEvent, toOutboxRow } from '@qc/events';
import type { Db } from '../../db.js';
import { Prisma, type Delivery, type DeliveryStatus } from '../../generated/prisma/client.js';
import type { IdentityPort, LocationStore, OrderAddress, OrderPort, RiderLocation } from '../../upstreams.js';

export const MAX_OTP_ATTEMPTS = 5;
const ACTIVE: DeliveryStatus[] = ['ASSIGNED', 'PICKED_UP'];
/** Orders a rider can be assigned to: accepted, not yet handed over. */
const ASSIGNABLE_ORDER_STATUSES = ['CONFIRMED', 'PACKED'];

/** The part of a transaction client `writeEvent` needs (works with the tenant-scoped client). */
type Tx = { outboxEvent: { create(args: { data: Prisma.OutboxEventUncheckedCreateInput }): PromiseLike<unknown> } };

export interface DeliveriesDeps {
  db: Db;
  logger: Logger;
  orders: OrderPort;
  identity: IdentityPort;
  locations: LocationStore;
  /** Outbox relay: publish right after a transaction that wrote events commits. */
  events?: { kick(): void };
  now?: () => Date;
}

const riderOf = (d: Delivery) => ({ id: d.riderId, name: d.riderName, phone: d.riderPhone });

/** Shop view: who delivers, how far along (never the OTP). */
function adminView(d: Delivery, location: RiderLocation | null) {
  return {
    id: d.id,
    orderId: d.orderId,
    orderNumber: d.orderNumber,
    status: d.status,
    rider: riderOf(d),
    otpAttemptsLeft: Math.max(MAX_OTP_ATTEMPTS - d.otpAttempts, 0),
    assignedAt: d.assignedAt,
    pickedUpAt: d.pickedUpAt,
    deliveredAt: d.deliveredAt,
    location,
  };
}

/** Rider view: where to go, whom to call, cash to collect (never the OTP). */
function riderView(d: Delivery) {
  return {
    id: d.id,
    orderId: d.orderId,
    orderNumber: d.orderNumber,
    status: d.status,
    customer: { name: d.customerName, phone: d.customerPhone },
    address: d.address as unknown as OrderAddress,
    note: d.note,
    itemCount: d.itemCount,
    totalPaise: d.totalPaise,
    codPaise: d.codPaise,
    otpAttemptsLeft: Math.max(MAX_OTP_ATTEMPTS - d.otpAttempts, 0),
    assignedAt: d.assignedAt,
    pickedUpAt: d.pickedUpAt,
    deliveredAt: d.deliveredAt,
  };
}

/** Customer view: the rider, the code to share at the door, where the rider is while on the way. */
function customerView(d: Delivery, location: RiderLocation | null) {
  return {
    orderId: d.orderId,
    status: d.status,
    rider: { name: d.riderName, phone: d.riderPhone },
    otp: ACTIVE.includes(d.status) ? d.otp : null,
    location: d.status === 'PICKED_UP' ? location : null,
  };
}

export type AdminDeliveryView = ReturnType<typeof adminView>;
export type RiderDeliveryView = ReturnType<typeof riderView>;

function otpMatches(expected: string, given: string): boolean {
  const a = Buffer.from(expected);
  const b = Buffer.from(given);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function createDeliveriesService({ db, logger, orders, identity, locations, events, now = () => new Date() }: DeliveriesDeps) {
  const userId = () => getContext()!.userId!;

  async function writeEvent(tx: Tx, d: Delivery, previousRiderId: string | null = null): Promise<void> {
    const event = buildEvent('delivery.status_changed', requireShopId(), {
      deliveryId: d.id,
      orderId: d.orderId,
      number: d.orderNumber,
      customerId: d.customerId,
      riderId: d.riderId,
      previousRiderId,
      status: d.status,
    });
    await tx.outboxEvent.create({ data: toOutboxRow(event) as Prisma.OutboxEventUncheckedCreateInput });
  }

  /**
   * Moves a delivery from one of `from` to `to` (conditional, so concurrent paths cannot both win)
   * and writes the event. Returns null when the delivery was not in `from` any more.
   */
  async function transition(id: string, from: DeliveryStatus[], to: DeliveryStatus, extra: Prisma.DeliveryUpdateManyMutationInput = {}) {
    const updated = await db.$transaction(async (tx) => {
      const { count } = await tx.delivery.updateMany({ where: { id, status: { in: from } }, data: { status: to, ...extra } });
      if (count === 0) return null;
      const row = await tx.delivery.findUniqueOrThrow({ where: { id } });
      await writeEvent(tx, row);
      return row;
    });
    if (updated) events?.kick();
    return updated;
  }

  async function mine(id: string): Promise<Delivery> {
    const d = await db.delivery.findFirst({ where: { id, riderId: userId() } });
    if (!d) throw Errors.notFound('DELIVERY_NOT_FOUND', 'Delivery not found');
    return d;
  }

  async function reread(id: string): Promise<Delivery> {
    return db.delivery.findUniqueOrThrow({ where: { id } });
  }

  /** Order already where we want it (a retry, or the shop did it): fine. Otherwise rethrow. */
  async function setOrderStatus(orderId: string, status: 'OUT_FOR_DELIVERY' | 'DELIVERED'): Promise<void> {
    try {
      await orders.setStatus(orderId, status);
    } catch (err) {
      if (err instanceof AppError && err.code === 'ORDER_STATUS_INVALID') {
        const order = await orders.get(orderId);
        if (order.status === status || (status === 'OUT_FOR_DELIVERY' && order.status === 'DELIVERED')) return;
        if (status === 'OUT_FOR_DELIVERY' && order.status !== 'PACKED') {
          throw Errors.conflict('ORDER_NOT_PACKED', 'The shop has not packed this order yet');
        }
        throw Errors.conflict('ORDER_CLOSED', 'This order can no longer be delivered');
      }
      throw err;
    }
  }

  return {
    // ---- Shop ----

    /** Riders of the shop with how many deliveries each has open. */
    async riders() {
      const riders = await identity.riders();
      const open = await db.delivery.groupBy({ by: ['riderId'], where: { status: { in: ACTIVE } }, _count: { _all: true } });
      const counts = new Map(open.map((o) => [o.riderId, o._count._all]));
      return riders.map((r) => ({ ...r, activeDeliveries: counts.get(r.id) ?? 0 }));
    },

    /** Assigns (or reassigns, before pickup) a rider to an accepted delivery order. Idempotent. */
    async assign(orderId: string, riderId: string) {
      const order = await orders.get(orderId);
      const existing = await db.delivery.findFirst({ where: { orderId } });
      if (existing && (existing.status === 'PICKED_UP' || existing.status === 'DELIVERED')) {
        throw Errors.conflict('DELIVERY_ALREADY_STARTED', 'The rider has already picked this order up');
      }
      if (order.fulfillment !== 'DELIVERY' || !order.address) {
        throw Errors.badRequest('NOT_A_DELIVERY_ORDER', 'This order is picked up at the shop');
      }
      if (!ASSIGNABLE_ORDER_STATUSES.includes(order.status)) {
        throw Errors.conflict('DELIVERY_NOT_ASSIGNABLE', 'Riders can be assigned after accepting and before the order leaves');
      }
      const rider = (await identity.riders()).find((r) => r.id === riderId);
      if (!rider) throw Errors.notFound('RIDER_NOT_FOUND', 'Rider not found');

      if (existing?.status === 'ASSIGNED' && existing.riderId === riderId) return adminView(existing, null);

      const shopId = requireShopId();
      const riderFields = { riderId, riderName: rider.name, riderPhone: rider.phone };
      const saved = await db.$transaction(async (tx) => {
        let row: Delivery;
        if (existing) {
          // Same row; the customer keeps the code they may already have seen.
          const { count } = await tx.delivery.updateMany({
            where: { id: existing.id, status: existing.status },
            data: { ...riderFields, status: 'ASSIGNED', assignedAt: now(), cancelledAt: null },
          });
          if (count === 0) throw Errors.conflict('DELIVERY_CHANGED', 'The delivery was updated meanwhile; try again');
          row = await tx.delivery.findUniqueOrThrow({ where: { id: existing.id } });
        } else {
          row = await tx.delivery.create({
            data: {
              shopId,
              orderId,
              orderNumber: order.number,
              customerId: order.customer.id,
              customerName: order.customer.name,
              customerPhone: order.customer.phone,
              address: order.address as unknown as Prisma.InputJsonValue,
              note: order.note,
              itemCount: order.itemCount,
              totalPaise: order.totalPaise,
              codPaise: order.paymentMethod === 'COD' ? order.totalPaise : 0,
              ...riderFields,
              otp: String(randomInt(0, 10_000)).padStart(4, '0'),
            },
          });
        }
        const previous = existing && existing.status === 'ASSIGNED' && existing.riderId !== riderId ? existing.riderId : null;
        await writeEvent(tx, row, previous);
        return row;
      }).catch((err: unknown) => {
        // Two assignments of a new delivery at once: the other one won.
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          throw Errors.conflict('DELIVERY_CHANGED', 'The delivery was updated meanwhile; try again');
        }
        throw err;
      });
      events?.kick();
      logger.info({ orderId, riderId }, existing ? 'rider reassigned' : 'rider assigned');
      return adminView(saved, null);
    },

    async forOrderAsAdmin(orderId: string) {
      const d = await db.delivery.findFirst({ where: { orderId } });
      if (!d) throw Errors.notFound('DELIVERY_NOT_FOUND', 'No rider assigned yet');
      return adminView(d, d.status === 'PICKED_UP' ? await locations.get(d.shopId, d.riderId) : null);
    },

    // ---- Customer ----

    async forOrderAsCustomer(orderId: string) {
      const d = await db.delivery.findFirst({ where: { orderId, customerId: userId() } });
      if (!d || d.status === 'CANCELLED') throw Errors.notFound('DELIVERY_NOT_FOUND', 'No rider assigned yet');
      return customerView(d, d.status === 'PICKED_UP' ? await locations.get(d.shopId, d.riderId) : null);
    },

    // ---- Rider ----

    async listMine(group: 'active' | 'done') {
      const rows = await db.delivery.findMany({
        where: { riderId: userId(), status: group === 'active' ? { in: ACTIVE } : { in: ['DELIVERED', 'CANCELLED'] } },
        orderBy: group === 'active' ? { assignedAt: 'asc' } : { updatedAt: 'desc' },
        take: 50,
      });
      return rows.map(riderView);
    },

    getMine: async (id: string) => riderView(await mine(id)),

    /** Rider has the parcel: the order goes OUT_FOR_DELIVERY (needs the shop to have packed it). */
    async pickUp(id: string) {
      const d = await mine(id);
      if (d.status === 'PICKED_UP') return riderView(d);
      if (d.status !== 'ASSIGNED') throw Errors.conflict('DELIVERY_CLOSED', 'This delivery is no longer yours to start');
      await setOrderStatus(d.orderId, 'OUT_FOR_DELIVERY');
      // The order event may already have moved the delivery (consumer): both paths end PICKED_UP.
      await transition(d.id, ['ASSIGNED'], 'PICKED_UP', { pickedUpAt: now() });
      return riderView(await reread(d.id));
    },

    /** At the door: the customer's code completes the order. */
    async deliver(id: string, otp: string) {
      const d = await mine(id);
      if (d.status === 'DELIVERED') return riderView(d);
      if (d.status !== 'PICKED_UP') throw Errors.conflict('DELIVERY_NOT_STARTED', 'Mark the order picked up first');

      // Count the attempt before comparing (atomic), so parallel guesses cannot exceed the limit.
      const { count } = await db.delivery.updateMany({
        where: { id: d.id, otpAttempts: { lt: MAX_OTP_ATTEMPTS } },
        data: { otpAttempts: { increment: 1 } },
      });
      if (count === 0) {
        throw new AppError('OTP_ATTEMPTS_EXCEEDED', 429, 'Too many wrong codes; ask the shop to mark the order delivered');
      }
      if (!otpMatches(d.otp, otp)) {
        throw new AppError('DELIVERY_OTP_INVALID', 400, 'Wrong delivery code', {
          attemptsLeft: MAX_OTP_ATTEMPTS - d.otpAttempts - 1,
        });
      }
      await setOrderStatus(d.orderId, 'DELIVERED');
      await transition(d.id, ['PICKED_UP'], 'DELIVERED', { deliveredAt: now() });
      return riderView(await reread(d.id));
    },

    /**
     * Rider's phone reports where it is. Stored only while the rider is on the way with an order;
     * returns who may see it (realtime forwards it to those customers and the shop).
     */
    async reportLocation(location: Omit<RiderLocation, 'at'>) {
      const onTheWay = await db.delivery.findMany({
        where: { riderId: userId(), status: 'PICKED_UP' },
        select: { orderId: true, customerId: true },
      });
      if (onTheWay.length === 0) return { targets: [], location: null };
      const stored: RiderLocation = { ...location, at: now().toISOString() };
      await locations.set(requireShopId(), userId(), stored);
      return { targets: onTheWay, location: stored };
    },

    // ---- Order events (consumer) ----

    /** Keeps the delivery in step when the shop acts on the order directly, or it is cancelled/rejected. */
    async onOrderStatus(orderId: string, status: string): Promise<void> {
      const d = await db.delivery.findFirst({ where: { orderId } });
      if (!d) return;
      if (status === 'CANCELLED' || status === 'REJECTED') {
        await transition(d.id, ACTIVE, 'CANCELLED', { cancelledAt: now() });
      } else if (status === 'OUT_FOR_DELIVERY') {
        await transition(d.id, ['ASSIGNED'], 'PICKED_UP', { pickedUpAt: now() });
      } else if (status === 'DELIVERED') {
        await transition(d.id, ACTIVE, 'DELIVERED', { deliveredAt: now() });
      }
    },
  };
}

export type DeliveriesService = ReturnType<typeof createDeliveriesService>;
