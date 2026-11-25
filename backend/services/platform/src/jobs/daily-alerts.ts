import type { Logger } from '@qc/common';
import type { PushSender } from '@qc/fcm';
import type { Db } from '../db.js';
import { niceDate, rupees } from '../format.js';
import type { Mailer } from '../mail/mailer.js';
import type { ShopDirectory } from '../modules/subscriptions/shop-directory.js';
import { GRACE_DAYS, addDays, istToday, statusOf } from '../modules/subscriptions/status.js';

export interface DailyAlertsDeps {
  db: Db;
  /** Phone notifications to the admin app (null = not configured: email instead). */
  push: PushSender | null;
  mailer: Mailer;
  directory: ShopDirectory;
  logger: Logger;
  now: () => Date;
  /** Fallback inbox when no admin phone is registered. */
  to: string;
}

const SEND_FROM_IST_HOUR = 9;
/** Android channel created by the admin app. */
export const ALERT_CHANNEL = 'alerts';
const day = (date: Date) => date.toISOString().slice(0, 10);
const daysBetween = (from: string, to: string) => Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);

/**
 * From 09:00 IST, at most once a day: tells the platform owner about shops that newly became overdue
 * (7 days after the due date) or whose extension ended. Each shop is announced once per due period
 * and kind (alert_log). One phone notification per shop to every registered admin phone; email only
 * when no phone can be reached, so an alert is never lost. Nothing is paused automatically.
 */
export async function runDailyAlerts({ db, push, mailer, directory, logger, now, to }: DailyAlertsDeps): Promise<{ sent: boolean; shops: number; via: 'push' | 'email' | null }> {
  const at = now();
  const today = istToday(at);
  const istHour = new Date(at.getTime() + 5.5 * 3600_000).getUTCHours();
  const none = { sent: false, shops: 0, via: null } as const;
  if (istHour < SEND_FROM_IST_HOUR) return none;
  if (await db.dailyMail.findUnique({ where: { day: new Date(`${today}T00:00:00Z`) } })) return none;

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
  if (pending.length === 0) return none;

  const shops = new Map((await directory.list()).map((s) => [s.id, s]));
  const subsById = new Map(subs.map((s) => [s.shopId, s]));
  const alerts = pending.map((a) => {
    const name = shops.get(a.shopId)?.name ?? subsById.get(a.shopId)?.slug ?? a.shopId;
    const due = day(a.dueDate);
    const body = `${rupees(subsById.get(a.shopId)?.feePaise ?? 0)} since ${niceDate(due)}`;
    const title = a.kind === 'extension_ended' ? `${name}: the extra 7 days are over` : `${name} is ${daysBetween(due, today)} days overdue`;
    return { shopId: a.shopId, title, body };
  });

  let via: 'push' | 'email' = 'email';
  const devices = push ? await db.adminDevice.findMany() : [];
  if (push && devices.length > 0) {
    const result = await push.send(
      alerts.flatMap((alert) =>
        devices.map((d) => ({ token: d.token, title: alert.title, body: alert.body, data: { shopId: alert.shopId }, channelId: ALERT_CHANNEL, tag: alert.shopId })),
      ),
    );
    if (result.invalidTokens.length) await db.adminDevice.deleteMany({ where: { token: { in: result.invalidTokens } } });
    if (result.sent > 0) via = 'push';
    else logger.warn('no admin phone took the overdue notification: sending an email instead');
  }
  if (via === 'email') {
    await mailer.send({
      to,
      subject: alerts.length === 1 ? alerts[0]!.title : `${alerts.length} shops need attention`,
      text: [
        'These shops have not paid the app subscription:',
        '',
        ...alerts.map((a) => `${a.title}: ${a.body}`),
        '',
        'Nothing was paused. Open the Shop Admin app to remind the owner, give 7 more days, or pause online orders.',
        '(This came by email because no phone with the Shop Admin app could get a notification.)',
      ].join('\n'),
    });
  }

  const sentAt = now();
  await db.$transaction([
    db.alertLog.updateMany({ where: { id: { in: pending.map((a) => a.id) } }, data: { sentAt } }),
    db.dailyMail.create({ data: { day: new Date(`${today}T00:00:00Z`), sentAt } }),
  ]);
  return { sent: true, shops: pending.length, via };
}
