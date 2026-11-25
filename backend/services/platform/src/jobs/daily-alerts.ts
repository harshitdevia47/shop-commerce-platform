import type { Db } from '../db.js';
import type { Mailer } from '../mail/mailer.js';
import type { ShopDirectory } from '../modules/subscriptions/shop-directory.js';
import { GRACE_DAYS, addDays, istToday, statusOf } from '../modules/subscriptions/status.js';
import { niceDate, rupees } from '../web/views.js';

export interface DailyAlertsDeps {
  db: Db;
  mailer: Mailer;
  directory: ShopDirectory;
  now: () => Date;
  /** Platform owner's inbox. */
  to: string;
  /** Admin site address, for links in the mail. */
  baseUrl: string;
}

const SEND_FROM_IST_HOUR = 9;
const day = (date: Date) => date.toISOString().slice(0, 10);
const daysBetween = (from: string, to: string) => Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);

/**
 * From 09:00 IST, at most one email a day listing shops that newly became overdue (7 days after the
 * due date) or whose extension ended. Each shop is listed once per due period and kind (alert_log),
 * so an unpaid shop does not fill the inbox every day. Nothing is paused automatically.
 */
export async function runDailyAlerts({ db, mailer, directory, now, to, baseUrl }: DailyAlertsDeps): Promise<{ sent: boolean; shops: number }> {
  const at = now();
  const today = istToday(at);
  const istHour = new Date(at.getTime() + 5.5 * 3600_000).getUTCHours();
  if (istHour < SEND_FROM_IST_HOUR) return { sent: false, shops: 0 };
  if (await db.dailyMail.findUnique({ where: { day: new Date(`${today}T00:00:00Z`) } })) return { sent: false, shops: 0 };

  // Record what crossed the line (idempotent: one row per shop, kind and due date).
  const subs = await db.subscription.findMany();
  const rows = subs
    .map((s) => ({ s, view: { nextDueDate: day(s.nextDueDate), extendedUntil: s.extendedUntil ? day(s.extendedUntil) : null, pausedAt: s.pausedAt } }))
    .filter(({ view }) => statusOf(view, today) === 'overdue')
    .map(({ s, view }) => ({
      shopId: s.shopId,
      kind: view.extendedUntil && view.extendedUntil > addDays(view.nextDueDate, GRACE_DAYS) ? 'extension_ended' : 'overdue',
      dueDate: s.nextDueDate,
    }));
  if (rows.length) await db.alertLog.createMany({ data: rows, skipDuplicates: true });

  const overdueNow = new Set(rows.map((r) => `${r.shopId}:${r.kind}:${day(r.dueDate)}`));
  const pending = (await db.alertLog.findMany({ where: { sentAt: null }, orderBy: { createdAt: 'asc' } })).filter((a) =>
    overdueNow.has(`${a.shopId}:${a.kind}:${day(a.dueDate)}`),
  );
  if (pending.length === 0) return { sent: false, shops: 0 };

  const shops = new Map((await directory.list()).map((s) => [s.id, s]));
  const subsById = new Map(subs.map((s) => [s.shopId, s]));
  const lines = pending.map((a) => {
    const name = shops.get(a.shopId)?.name ?? subsById.get(a.shopId)?.slug ?? a.shopId;
    const due = day(a.dueDate);
    const fee = rupees(subsById.get(a.shopId)?.feePaise ?? 0);
    const what = a.kind === 'extension_ended' ? 'extra 7 days are over' : `${daysBetween(due, today)} days`;
    return { name, text: `${name}: ${fee} due since ${niceDate(due)} (${what})\n  ${baseUrl}/shops/${a.shopId}` };
  });

  const single = pending.length === 1 ? pending[0]! : null;
  const subject = single
    ? single.kind === 'extension_ended'
      ? `${lines[0]!.name}: the extra 7 days are over`
      : `${lines[0]!.name} is ${daysBetween(day(single.dueDate), today)} days overdue`
    : pending.every((a) => a.kind === 'overdue')
      ? `${pending.length} shops are ${GRACE_DAYS} days overdue`
      : `${pending.length} shops need attention`;

  await mailer.send({
    to,
    subject,
    text: [
      'These shops have not paid the app subscription:',
      '',
      ...lines.map((l) => l.text),
      '',
      'Nothing was paused. Open a shop to remind the owner, give 7 more days, or pause online orders.',
    ].join('\n'),
  });

  const sentAt = now();
  await db.$transaction([
    db.alertLog.updateMany({ where: { id: { in: pending.map((a) => a.id) } }, data: { sentAt } }),
    db.dailyMail.create({ data: { day: new Date(`${today}T00:00:00Z`), sentAt } }),
  ]);
  return { sent: true, shops: pending.length };
}
