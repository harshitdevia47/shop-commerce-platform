import { Errors, getContext, isRole, ADMIN_ROLES, requireShopId, type ShopConfigSource } from '@qc/common';
import type { PaymentsConfig } from '@qc/config-schema';
import { buildEvent, toOutboxRow, type EventType } from '@qc/events';
import type { Db } from '../../db.js';
import { Prisma, type Payment, type PaymentMethod, type PaymentStatus } from '../../generated/prisma/client.js';
import { PROVIDERS } from '../../providers/payment-provider.js';

export interface CreatePaymentInput {
  orderId: string;
  orderNumber: number;
  customerId: string;
  method: PaymentMethod;
  amountPaise: number;
}

export function createPaymentsService(
  db: Db,
  config: ShopConfigSource<{ payments: PaymentsConfig }>,
  now: () => Date = () => new Date(),
  events?: { kick(): void },
) {
  /** Updates a payment and writes the matching event in one transaction. */
  async function updateWithEvent(
    payment: Payment,
    data: Prisma.PaymentUpdateInput,
    type: Extract<EventType, 'payment.utr_submitted' | 'payment.marked_paid'>,
  ): Promise<Payment> {
    const updated = await db.$transaction(async (tx) => {
      const row = await tx.payment.update({ where: { id: payment.id }, data });
      const event = buildEvent(type, requireShopId(), {
        orderId: row.orderId,
        orderNumber: row.orderNumber,
        customerId: row.customerId,
        amountPaise: row.amountPaise,
      });
      await tx.outboxEvent.create({ data: toOutboxRow(event) as Prisma.OutboxEventUncheckedCreateInput });
      return row;
    });
    events?.kick();
    return updated;
  }

  async function toPublic(payment: Payment) {
    const live = payment.status === 'PENDING' || payment.status === 'SUBMITTED';
    const instructions = live ? PROVIDERS[payment.method].instructions(payment, (await config.get()).payments) : {};
    return {
      id: payment.id,
      orderId: payment.orderId,
      orderNumber: payment.orderNumber,
      method: payment.method,
      status: payment.status,
      amountPaise: payment.amountPaise,
      utr: payment.utr,
      paidAt: payment.paidAt,
      ...instructions,
    };
  }

  /** Customers see only their own payments; shop admins see all of the shop's. */
  async function findVisible(orderId: string): Promise<Payment> {
    const context = getContext();
    const isAdmin = isRole(context?.role) && ADMIN_ROLES.includes(context.role);
    const payment = await db.payment.findFirst({
      where: { orderId, ...(isAdmin ? {} : { customerId: context?.userId ?? '00000000-0000-0000-0000-000000000000' }) },
    });
    if (!payment) throw Errors.notFound('PAYMENT_NOT_FOUND', 'Payment not found');
    return payment;
  }

  return {
    toPublic,

    /** Called by the order saga. Idempotent per order. */
    async create(input: CreatePaymentInput) {
      const existing = await db.payment.findFirst({ where: { orderId: input.orderId } });
      if (existing) return toPublic(existing);
      if (!PROVIDERS[input.method].isEnabled((await config.get()).payments)) {
        throw Errors.badRequest('PAYMENT_METHOD_UNAVAILABLE', 'This shop does not accept that payment method');
      }
      try {
        return toPublic(await db.payment.create({ data: { ...input, shopId: requireShopId() } }));
      } catch (err) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          return toPublic(await db.payment.findFirstOrThrow({ where: { orderId: input.orderId } }));
        }
        throw err;
      }
    },

    /** Order cancelled/rejected/failed. Paid payments stay PAID (refunds are handled by the owner). */
    async void(orderId: string): Promise<{ status: PaymentStatus | null }> {
      await db.payment.updateMany({ where: { orderId, status: { in: ['PENDING', 'SUBMITTED'] } }, data: { status: 'VOID' } });
      const payment = await db.payment.findFirst({ where: { orderId } });
      return { status: payment?.status ?? null };
    },

    /** The order exists (order.placed or the sweeper's check): never void it as an orphan. */
    async confirmOrder(orderId: string): Promise<void> {
      await db.payment.updateMany({ where: { orderId, orderConfirmedAt: null }, data: { orderConfirmedAt: now() } });
    },

    get: async (orderId: string) => toPublic(await findVisible(orderId)),

    async submitUtr(orderId: string, utr: string) {
      const payment = await findVisible(orderId);
      if (payment.method !== 'UPI') throw Errors.badRequest('PAYMENT_NOT_UPI', 'Only UPI payments take a UTR');
      if (payment.status !== 'PENDING' && payment.status !== 'SUBMITTED') {
        throw Errors.conflict('PAYMENT_CLOSED', 'This payment can no longer be changed');
      }
      return toPublic(await updateWithEvent(payment, { utr, utrAt: now(), status: 'SUBMITTED' }, 'payment.utr_submitted'));
    },

    async markPaid(orderId: string) {
      const payment = await findVisible(orderId);
      if (payment.status === 'PAID') return toPublic(payment);
      if (payment.status === 'VOID') throw Errors.conflict('PAYMENT_CLOSED', 'This order was cancelled');
      return toPublic(
        await updateWithEvent(payment, { status: 'PAID', paidAt: now(), paidBy: getContext()!.userId! }, 'payment.marked_paid'),
      );
    },

    /** Admin: payments waiting for confirmation (UTR submitted) first, newest first. */
    async listForAdmin(status?: PaymentStatus) {
      const rows = await db.payment.findMany({
        where: status ? { status } : {},
        orderBy: [{ id: 'desc' }],
        take: 100,
      });
      return Promise.all(rows.map(toPublic));
    },
  };
}

export type PaymentsService = ReturnType<typeof createPaymentsService>;
