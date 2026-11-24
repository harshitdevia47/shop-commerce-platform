import { Errors, getContext, requireShopId, type Logger, type ShopConfigSource } from '@qc/common';
import type { RuntimeConfig } from '@qc/config-schema';
import { buildEvent, toOutboxRow } from '@qc/events';
import type { Db } from '../../db.js';
import { Prisma, type ReturnStatus, type ReturnType as ReturnKind } from '../../generated/prisma/client.js';
import type { MediaPort } from '../../upstreams.js';
import { toReturnView, type Attachment } from '../orders/orders.service.js';

export interface ReturnInput {
  type: ReturnKind;
  reason: string;
  items: { variantId: string; qty: number }[];
  photoIds?: string[];
}

/** REQUESTED → APPROVED | REJECTED, APPROVED → COMPLETED. */
const NEXT: Record<ReturnStatus, ReturnStatus[]> = {
  REQUESTED: ['APPROVED', 'REJECTED'],
  APPROVED: ['COMPLETED'],
  REJECTED: [],
  COMPLETED: [],
};

export interface ReturnsDeps {
  db: Db;
  logger: Logger;
  shopConfig: ShopConfigSource<RuntimeConfig>;
  media?: MediaPort;
  events?: { kick(): void };
  now?: () => Date;
}

/**
 * Returns and exchanges (feature `returns`). The shop decides; money back or the replacement is
 * handled at the shop (cash / UPI) and recorded by completing the request.
 */
export function createReturnsService({ db, logger, shopConfig, media, events, now = () => new Date() }: ReturnsDeps) {
  const userId = () => getContext()!.userId!;

  async function enabled(): Promise<RuntimeConfig> {
    const config = await shopConfig.get();
    if (!config.features.returns) throw Errors.badRequest('FEATURE_DISABLED', 'This shop does not take returns');
    return config;
  }

  return {
    async request(orderId: string, input: ReturnInput) {
      const config = await enabled();
      if (input.type === 'EXCHANGE' && !config.returns.allowExchange) {
        throw Errors.badRequest('EXCHANGE_NOT_OFFERED', 'This shop takes returns only');
      }
      const order = await db.order.findFirst({
        where: { id: orderId, customerId: userId() },
        include: { items: true, history: { orderBy: { createdAt: 'desc' } } },
      });
      if (!order) throw Errors.notFound('ORDER_NOT_FOUND', 'Order not found');
      if (order.status !== 'DELIVERED' && order.status !== 'PICKED_UP') {
        throw Errors.conflict('RETURN_NOT_ALLOWED', 'Returns are possible after the order is delivered');
      }
      const handedOver = order.history.find((h) => h.to === order.status)?.createdAt ?? order.updatedAt;
      if (now().getTime() - handedOver.getTime() > config.returns.windowDays * 86_400_000) {
        throw Errors.conflict('RETURN_WINDOW_CLOSED', `Returns are accepted within ${config.returns.windowDays} days`);
      }

      // Items must be from this order, at most the quantity bought. List orders have no items to pick.
      const bought = new Map(order.items.map((i) => [i.variantId, i]));
      if (order.items.length > 0 && input.items.length === 0) throw Errors.badRequest('RETURN_ITEMS_REQUIRED', 'Choose the items');
      const items = input.items.map((line) => {
        const item = bought.get(line.variantId);
        if (!item || line.qty > item.qty) throw Errors.badRequest('RETURN_ITEMS_INVALID', 'Choose items and quantities from this order');
        return { variantId: item.variantId, productName: item.productName, variantLabel: item.variantLabel, qty: line.qty };
      });
      if (new Set(items.map((i) => i.variantId)).size !== items.length) {
        throw Errors.badRequest('RETURN_ITEMS_INVALID', 'Each item once');
      }
      const photos: Attachment[] = input.photoIds?.length
        ? ((await media?.claim([...new Set(input.photoIds)], userId(), ['RETURN_PHOTO'])) ?? [])
        : [];

      try {
        const created = await db.$transaction(async (tx) => {
          const row = await tx.returnRequest.create({
            data: {
              shopId: requireShopId(),
              orderId,
              customerId: userId(),
              type: input.type,
              reason: input.reason,
              items: items as unknown as Prisma.InputJsonValue,
              photos: photos.length ? (photos as unknown as Prisma.InputJsonValue) : Prisma.DbNull,
            },
          });
          const event = buildEvent('return.requested', requireShopId(), {
            returnId: row.id,
            orderId,
            number: order.number,
            customerId: order.customerId,
            type: row.type,
          });
          await tx.outboxEvent.create({ data: toOutboxRow(event) as Prisma.OutboxEventUncheckedCreateInput });
          return row;
        });
        events?.kick();
        logger.info({ orderId, returnId: created.id, type: created.type }, 'return requested');
        return toReturnView(created, order.number);
      } catch (err) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          throw Errors.conflict('RETURN_ALREADY_REQUESTED', 'A return was already requested for this order');
        }
        throw err;
      }
    },

    /** Shop: open requests first (oldest first), then recent closed ones. */
    async listForShop(status?: ReturnStatus) {
      await enabled();
      const rows = await db.returnRequest.findMany({
        where: status ? { status } : {},
        include: { order: { select: { number: true } } },
        orderBy: [{ createdAt: status === 'REQUESTED' ? 'asc' : 'desc' }],
        take: 100,
      });
      return rows.map((r) => toReturnView(r, r.order.number));
    },

    async setStatus(id: string, to: ReturnStatus, note?: string) {
      await enabled();
      const current = await db.returnRequest.findFirst({ where: { id }, include: { order: { select: { number: true } } } });
      if (!current) throw Errors.notFound('RETURN_NOT_FOUND', 'Return request not found');
      if (!NEXT[current.status].includes(to)) {
        throw Errors.conflict('RETURN_STATUS_INVALID', `Cannot change a return from ${current.status} to ${to}`);
      }
      if (to === 'REJECTED' && !note) throw Errors.badRequest('REASON_REQUIRED', 'Tell the customer why');
      const updated = await db.$transaction(async (tx) => {
        const { count } = await tx.returnRequest.updateMany({
          where: { id, status: current.status },
          data: { status: to, ...(note ? { shopNote: note } : {}) },
        });
        if (count === 0) throw Errors.conflict('RETURN_CHANGED', 'The request was updated by someone else');
        const row = await tx.returnRequest.findUniqueOrThrow({ where: { id } });
        const event = buildEvent('return.status_changed', requireShopId(), {
          returnId: id,
          orderId: row.orderId,
          number: current.order.number,
          customerId: row.customerId,
          type: row.type,
          status: to as 'APPROVED' | 'REJECTED' | 'COMPLETED',
          note: row.shopNote,
        });
        await tx.outboxEvent.create({ data: toOutboxRow(event) as Prisma.OutboxEventUncheckedCreateInput });
        return row;
      });
      events?.kick();
      return toReturnView(updated, current.order.number);
    },
  };
}

export type ReturnsService = ReturnType<typeof createReturnsService>;
