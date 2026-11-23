import { AppError, requireShopId } from '@qc/common';
import type { Db } from '../../db.js';
import { Prisma } from '../../generated/prisma/client.js';

type I18n = Record<string, string> | null;

/** What the order service needs to price and snapshot a cart line. */
export interface VariantSnapshot {
  variantId: string;
  productId: string;
  productName: string;
  productNameI18n: I18n;
  label: string;
  labelI18n: I18n;
  pricePaise: number;
  mrpPaise: number | null;
  thumbUrl: string | null;
  /** Product active, not deleted, variant available and (if tracked) stock > 0. */
  inStock: boolean;
  /** null = untracked. */
  stockQty: number | null;
}

export interface ReserveItem {
  variantId: string;
  qty: number;
}

export interface Shortage {
  variantId: string;
  requested: number;
  available: number;
}

const sellable = {
  deletedAt: null,
  isAvailable: true,
  product: { deletedAt: null, isActive: true },
} satisfies Prisma.VariantWhereInput;

export function createStockService(db: Db, now: () => Date = () => new Date()) {
  /** Stock each item could get right now (for a precise error). */
  async function shortages(items: ReserveItem[]): Promise<Shortage[]> {
    const variants = await db.variant.findMany({
      where: { id: { in: items.map((i) => i.variantId) } },
      include: { product: { select: { deletedAt: true, isActive: true } } },
    });
    const byId = new Map(variants.map((v) => [v.id, v]));
    return items.flatMap((item) => {
      const v = byId.get(item.variantId);
      const sellableNow = v && !v.deletedAt && v.isAvailable && !v.product.deletedAt && v.product.isActive;
      const available = !sellableNow ? 0 : v.stockQty === null ? item.qty : v.stockQty;
      return available >= item.qty ? [] : [{ variantId: item.variantId, requested: item.qty, available }];
    });
  }

  return {
    /** Current price/name/stock of variants of this shop. Unknown ids are left out. */
    async lookup(ids: string[]): Promise<VariantSnapshot[]> {
      const variants = await db.variant.findMany({
        where: { id: { in: ids } },
        include: {
          product: {
            select: {
              id: true,
              name: true,
              nameI18n: true,
              isActive: true,
              deletedAt: true,
              images: { orderBy: { sortOrder: 'asc' }, take: 1, select: { thumbUrl: true } },
            },
          },
        },
      });
      return variants.map((v) => ({
        variantId: v.id,
        productId: v.product.id,
        productName: v.product.name,
        productNameI18n: (v.product.nameI18n as I18n) ?? null,
        label: v.label,
        labelI18n: (v.labelI18n as I18n) ?? null,
        pricePaise: v.pricePaise,
        mrpPaise: v.mrpPaise,
        thumbUrl: v.product.images[0]?.thumbUrl ?? null,
        inStock:
          !v.deletedAt &&
          v.isAvailable &&
          !v.product.deletedAt &&
          v.product.isActive &&
          (v.stockQty === null || v.stockQty > 0),
        stockQty: v.stockQty,
      }));
    },

    /**
     * Holds stock for an order, all or nothing. Each tracked variant is decremented with a
     * conditional update (`stock_qty >= qty`), so concurrent orders can never oversell.
     * Idempotent: a second call for the same order is a no-op.
     */
    async reserve(orderId: string, items: ReserveItem[]): Promise<void> {
      const merged = new Map<string, number>();
      for (const item of items) merged.set(item.variantId, (merged.get(item.variantId) ?? 0) + item.qty);
      const lines = [...merged].map(([variantId, qty]) => ({ variantId, qty }));

      // Throwing (not returning) inside the transaction is what rolls back earlier decrements.
      const shortage = new Error('shortage');
      const failed = await db
        .$transaction(async (tx) => {
          if ((await tx.stockReservation.count({ where: { orderId } })) > 0) return false;
          for (const line of lines) {
            const variant = await tx.variant.findFirst({ where: { id: line.variantId, ...sellable }, select: { stockQty: true } });
            if (!variant) throw shortage;
            const tracked = variant.stockQty !== null;
            if (tracked) {
              const updated = await tx.variant.updateMany({
                where: { id: line.variantId, ...sellable, stockQty: { gte: line.qty } },
                data: { stockQty: { decrement: line.qty } },
              });
              if (updated.count === 0) throw shortage;
            }
            await tx.stockReservation.create({
              data: { shopId: requireShopId(), orderId, variantId: line.variantId, qty: line.qty, tracked },
            });
          }
          return false;
        })
        .catch((err: unknown) => {
          if (err === shortage) return true;
          // A parallel call for the same order won the race: its reservation stands.
          if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') return false;
          throw err;
        });

      if (failed) {
        throw new AppError('OUT_OF_STOCK', 409, 'Some items are no longer available in the requested quantity', {
          items: await shortages(lines),
        });
      }
    },

    /** Gives held stock back (order cancelled/rejected/failed). Idempotent. */
    async release(orderId: string): Promise<void> {
      await db.$transaction(async (tx) => {
        const held = await tx.stockReservation.findMany({ where: { orderId, releasedAt: null } });
        for (const reservation of held) {
          const claimed = await tx.stockReservation.updateMany({
            where: { id: reservation.id, releasedAt: null },
            data: { releasedAt: now() },
          });
          if (claimed.count === 1 && reservation.tracked) {
            // stock_qty may have been switched to untracked (null) meanwhile; null + n stays null.
            await tx.variant.updateMany({
              where: { id: reservation.variantId },
              data: { stockQty: { increment: reservation.qty } },
            });
          }
        }
      });
    },
  };
}

export type StockService = ReturnType<typeof createStockService>;
