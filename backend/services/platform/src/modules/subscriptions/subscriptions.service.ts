import { AppError, Errors, type Logger } from '@qc/common';
import type { Db } from '../../db.js';
import { Prisma, type Subscription, type SubscriptionPayment } from '../../generated/prisma/client.js';
import type { ShopDirectory, ShopSummary } from './shop-directory.js';
import { STATUS_ORDER, addMonths, appStateOf, firstDueDate, istToday, nextOverduePoint, statusOf, type Status } from './status.js';

export interface SubscriptionView {
  shopId: string;
  slug: string;
  feePaise: number;
  dueDay: number;
  nextDueDate: string;
  extendedUntil: string | null;
  pausedAt: Date | null;
  logoDone: boolean;
  playDone: boolean;
}

export interface PaymentView {
  id: string;
  amountPaise: number;
  upiRef: string | null;
  paidOn: string;
  months: number;
  note: string | null;
  recordedBy: string;
}

export interface OverviewRow {
  shop: ShopSummary;
  subscription: SubscriptionView | null;
  status: Status;
}

export interface MarkPaidInput {
  amountPaise: number;
  upiRef?: string;
  /** YYYY-MM-DD */
  paidOn: string;
  months: number;
  note?: string;
  /** Admin email. */
  by: string;
  formId?: string;
}

export type ActionResult = 'done' | 'repeat';

export interface SubscriptionsDeps {
  db: Db;
  directory: ShopDirectory;
  logger: Logger;
  /** Platform owner's UPI ID, shown to shop owners. */
  payTo?: string;
  now?: () => Date;
}

const day = (date: Date) => date.toISOString().slice(0, 10);
const dbDate = (value: string) => new Date(`${value}T00:00:00Z`);

const toView = (s: Subscription): SubscriptionView => ({
  shopId: s.shopId,
  slug: s.slug,
  feePaise: s.feePaise,
  dueDay: s.dueDay,
  nextDueDate: day(s.nextDueDate),
  extendedUntil: s.extendedUntil ? day(s.extendedUntil) : null,
  pausedAt: s.pausedAt,
  logoDone: s.logoDone,
  playDone: s.playDone,
});

const toPayment = (p: SubscriptionPayment): PaymentView => ({
  id: p.id,
  amountPaise: p.amountPaise,
  upiRef: p.upiRef,
  paidOn: day(p.paidOn),
  months: p.months,
  note: p.note,
  recordedBy: p.recordedBy,
});

/** Subscriptions of shops to the platform: setup, payments, extensions, pause, and the app state. */
export function createSubscriptionsService({ db, directory, logger, payTo, now = () => new Date() }: SubscriptionsDeps) {
  const today = () => istToday(now());

  async function find(shopId: string): Promise<Subscription> {
    const sub = await db.subscription.findUnique({ where: { shopId } });
    if (!sub) throw Errors.notFound('SUBSCRIPTION_NOT_FOUND', 'This shop has no subscription yet');
    return sub;
  }

  /** True the first time a form id is seen; false for a repeated submit. */
  async function claimForm(formId: string | undefined): Promise<boolean> {
    if (!formId) return true;
    try {
      await db.usedForm.create({ data: { id: formId } });
      return true;
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') return false;
      throw err;
    }
  }

  /** Tells tenant what the apps should show. A failure is logged; the hourly push repairs it. */
  async function push(sub: Subscription): Promise<void> {
    const view = toView(sub);
    try {
      await directory.pushState(sub.shopId, appStateOf(statusOf(view, today()), view, payTo));
    } catch (err) {
      logger.error({ err, shopId: sub.shopId }, 'could not update the shop app state (retried hourly)');
    }
  }

  async function change(shopId: string, formId: string | undefined, data: (sub: Subscription) => Prisma.SubscriptionUpdateInput): Promise<ActionResult> {
    const sub = await find(shopId);
    if (!(await claimForm(formId))) return 'repeat';
    await push(await db.subscription.update({ where: { shopId }, data: data(sub) }));
    return 'done';
  }

  return {
    async overview(): Promise<OverviewRow[]> {
      const [shops, subs] = await Promise.all([directory.list(), db.subscription.findMany()]);
      const bySub = new Map(subs.map((s) => [s.shopId, toView(s)]));
      const t = today();
      return shops
        .map((shop) => {
          const subscription = bySub.get(shop.id) ?? null;
          return { shop, subscription, status: statusOf(subscription, t) };
        })
        .sort((a, b) => STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status) || a.shop.name.localeCompare(b.shop.name));
    },

    async get(shopId: string): Promise<{ subscription: SubscriptionView | null; payments: PaymentView[]; status: Status }> {
      const sub = await db.subscription.findUnique({ where: { shopId }, include: { payments: { orderBy: [{ paidOn: 'desc' }, { createdAt: 'desc' }] } } });
      const subscription = sub ? toView(sub) : null;
      return { subscription, payments: sub?.payments.map(toPayment) ?? [], status: statusOf(subscription, today()) };
    },

    async setup(shopId: string, input: { feePaise: number; dueDay: number; formId?: string }): Promise<ActionResult> {
      const shop = (await directory.list()).find((s) => s.id === shopId);
      if (!shop) throw Errors.notFound('SHOP_NOT_FOUND', 'Shop not found');
      if (await db.subscription.findUnique({ where: { shopId } })) throw new AppError('SUBSCRIPTION_EXISTS', 409, 'This shop already has a subscription');
      if (!(await claimForm(input.formId))) return 'repeat';
      const sub = await db.subscription.create({
        data: { shopId, slug: shop.slug, feePaise: input.feePaise, dueDay: input.dueDay, nextDueDate: dbDate(firstDueDate(today(), input.dueDay)) },
      });
      await push(sub);
      return 'done';
    },

    /** New fee and due day; the next due date keeps its month and takes the new day. */
    edit: (shopId: string, input: { feePaise: number; dueDay: number; formId?: string }) =>
      change(shopId, input.formId, (sub) => ({
        feePaise: input.feePaise,
        dueDay: input.dueDay,
        nextDueDate: dbDate(addMonths(day(sub.nextDueDate), 0, input.dueDay)),
      })),

    async markPaid(shopId: string, input: MarkPaidInput): Promise<ActionResult> {
      const sub = await find(shopId);
      if (!(await claimForm(input.formId))) return 'repeat';
      const [, updated] = await db.$transaction([
        db.subscriptionPayment.create({
          data: {
            shopId,
            amountPaise: input.amountPaise,
            upiRef: input.upiRef || null,
            paidOn: dbDate(input.paidOn),
            months: input.months,
            note: input.note || null,
            recordedBy: input.by,
          },
        }),
        db.subscription.update({
          where: { shopId },
          data: { nextDueDate: dbDate(addMonths(day(sub.nextDueDate), input.months, sub.dueDay)), extendedUntil: null, pausedAt: null },
        }),
      ]);
      await push(updated);
      return 'done';
    },

    extend: (shopId: string, formId?: string) =>
      change(shopId, formId, (sub) => ({ extendedUntil: dbDate(nextOverduePoint(toView(sub), today())) })),

    pause: (shopId: string, formId?: string) => change(shopId, formId, (sub) => ({ pausedAt: sub.pausedAt ?? now() })),

    resume: (shopId: string, formId?: string) => change(shopId, formId, () => ({ pausedAt: null })),

    setChecklist: (shopId: string, ticks: { logoDone?: boolean; playDone?: boolean }) => change(shopId, undefined, () => ticks),

    /** Hourly: date-driven changes (ok → due) reach the apps, and failed pushes are repaired. */
    async pushAll(): Promise<{ pushed: number; failed: number }> {
      const subs = await db.subscription.findMany();
      let failed = 0;
      for (const sub of subs) {
        const view = toView(sub);
        try {
          await directory.pushState(sub.shopId, appStateOf(statusOf(view, today()), view, payTo));
        } catch (err) {
          failed++;
          logger.error({ err, shopId: sub.shopId }, 'hourly push of the app state failed');
        }
      }
      return { pushed: subs.length - failed, failed };
    },
  };
}

export type SubscriptionsService = ReturnType<typeof createSubscriptionsService>;
