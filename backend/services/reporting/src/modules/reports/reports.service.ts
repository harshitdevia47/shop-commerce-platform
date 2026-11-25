import { Errors } from '@qc/common';
import type { Db } from '../../db.js';
import type { Prisma } from '../../generated/prisma/client.js';

/** Orders that never became sales. */
const FAILED = ['CANCELLED', 'REJECTED'];
const COMPLETED = ['DELIVERED', 'PICKED_UP'];
export const MAX_RANGE_DAYS = 366;

export interface DayRange {
  from: Date;
  to: Date;
}

/** `YYYY-MM-DD` shop days, inclusive, at most a year. */
export function parseRange(from: string, to: string): DayRange {
  const start = new Date(`${from}T00:00:00.000Z`);
  const end = new Date(`${to}T00:00:00.000Z`);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) {
    throw Errors.badRequest('RANGE_INVALID', 'Choose a start date on or before the end date');
  }
  if ((end.getTime() - start.getTime()) / 86_400_000 + 1 > MAX_RANGE_DAYS) {
    throw Errors.badRequest('RANGE_TOO_LONG', `Choose at most ${MAX_RANGE_DAYS} days`);
  }
  return { from: start, to: end };
}

const day = (d: Date) => d.toISOString().slice(0, 10);

export function createReportsService(db: Db) {
  const inRange = (range: DayRange): Prisma.SaleOrderWhereInput => ({ placedDay: { gte: range.from, lte: range.to } });
  const sold = (range: DayRange): Prisma.SaleOrderWhereInput => ({ ...inRange(range), status: { notIn: FAILED } });

  return {
    /**
     * The owner's numbers for a period. "Sales" = orders placed in the period that were not
     * cancelled or rejected (list orders count once the shop priced them).
     */
    async summary(range: DayRange) {
      const [byStatus, byMethod, byFulfillment, orders] = await Promise.all([
        db.saleOrder.groupBy({ by: ['status'], where: inRange(range), _count: { _all: true }, _sum: { totalPaise: true } }),
        db.saleOrder.groupBy({ by: ['paymentMethod'], where: sold(range), _count: { _all: true }, _sum: { totalPaise: true } }),
        db.saleOrder.groupBy({ by: ['fulfillment'], where: sold(range), _count: { _all: true } }),
        db.saleOrder.findMany({ where: sold(range), select: { orderId: true, customerId: true, totalPaise: true, status: true } }),
      ]);

      const count = (statuses: string[]) => byStatus.filter((s) => statuses.includes(s.status)).reduce((n, s) => n + s._count._all, 0);
      const salesPaise = orders.reduce((n, o) => n + o.totalPaise, 0);
      const completed = orders.filter((o) => COMPLETED.includes(o.status));

      const paidIds = new Set(
        (await db.salePayment.findMany({ where: { orderId: { in: orders.map((o) => o.orderId) } }, select: { orderId: true } })).map(
          (p) => p.orderId,
        ),
      );
      const paidPaise = orders.filter((o) => paidIds.has(o.orderId)).reduce((n, o) => n + o.totalPaise, 0);

      // New customer = first order ever (in this shop) falls in the period.
      const customers = [...new Set(orders.map((o) => o.customerId))];
      const firsts = customers.length
        ? await db.saleOrder.groupBy({ by: ['customerId'], where: { customerId: { in: customers } }, _min: { placedDay: true } })
        : [];
      const newCustomers = firsts.filter((f) => f._min.placedDay !== null && f._min.placedDay >= range.from).length;

      const method = (m: string) => byMethod.find((b) => b.paymentMethod === m);
      return {
        from: day(range.from),
        to: day(range.to),
        orders: orders.length,
        cancelled: count(FAILED),
        open: orders.length - completed.length,
        completed: completed.length,
        salesPaise,
        completedPaise: completed.reduce((n, o) => n + o.totalPaise, 0),
        averageOrderPaise: orders.length ? Math.round(salesPaise / orders.length) : 0,
        paidPaise,
        cod: { orders: method('COD')?._count._all ?? 0, paise: method('COD')?._sum.totalPaise ?? 0 },
        upi: { orders: method('UPI')?._count._all ?? 0, paise: method('UPI')?._sum.totalPaise ?? 0 },
        online: { orders: method('RAZORPAY')?._count._all ?? 0, paise: method('RAZORPAY')?._sum.totalPaise ?? 0 },
        delivery: byFulfillment.find((f) => f.fulfillment === 'DELIVERY')?._count._all ?? 0,
        pickup: byFulfillment.find((f) => f.fulfillment === 'PICKUP')?._count._all ?? 0,
        customers: customers.length,
        newCustomers,
        returningCustomers: customers.length - newCustomers,
      };
    },

    /** Platform admin: sales since a shop day, and when the last order (any status) came in. */
    async monthStats(from: Date) {
      const [agg, last] = await Promise.all([
        db.saleOrder.aggregate({ where: { placedDay: { gte: from }, status: { notIn: FAILED } }, _count: { _all: true }, _sum: { totalPaise: true } }),
        db.saleOrder.findFirst({ orderBy: { placedAt: 'desc' }, select: { placedAt: true } }),
      ]);
      return { orders: agg._count._all, salesPaise: agg._sum.totalPaise ?? 0, lastOrderAt: last?.placedAt.toISOString() ?? null };
    },

    /** Sales per day, every day of the period (zero days included, for charts). */
    async daily(range: DayRange) {
      const rows = await db.saleOrder.groupBy({
        by: ['placedDay'],
        where: sold(range),
        _count: { _all: true },
        _sum: { totalPaise: true },
      });
      const byDay = new Map(rows.map((r) => [day(r.placedDay), r]));
      const out: { day: string; orders: number; salesPaise: number }[] = [];
      for (let t = range.from.getTime(); t <= range.to.getTime(); t += 86_400_000) {
        const key = day(new Date(t));
        const row = byDay.get(key);
        out.push({ day: key, orders: row?._count._all ?? 0, salesPaise: row?._sum.totalPaise ?? 0 });
      }
      return out;
    },

    /** Best sellers by revenue (quantity as tie-breaker), from orders that were not cancelled/rejected. */
    async topProducts(range: DayRange, limit: number) {
      const rows = await db.saleItem.groupBy({
        by: ['productId'],
        where: { placedDay: { gte: range.from, lte: range.to }, order: { status: { notIn: FAILED } } },
        _sum: { qty: true, lineTotalPaise: true },
        orderBy: [{ _sum: { lineTotalPaise: 'desc' } }, { _sum: { qty: 'desc' } }],
        take: limit,
      });
      const names = await db.saleItem.findMany({
        where: { productId: { in: rows.map((r) => r.productId) } },
        select: { productId: true, productName: true },
        orderBy: { placedDay: 'desc' },
        distinct: ['productId'],
      });
      const nameOf = new Map(names.map((n) => [n.productId, n.productName]));
      return rows.map((r) => ({
        productId: r.productId,
        productName: nameOf.get(r.productId) ?? '',
        qty: r._sum.qty ?? 0,
        salesPaise: r._sum.lineTotalPaise ?? 0,
      }));
    },
  };
}

export type ReportsService = ReturnType<typeof createReportsService>;
