/**
 * Subscription rules. Dates are shop calendar days (IST) as `YYYY-MM-DD` strings, compared as
 * strings (same format, so lexical order = date order).
 */
import type { SubscriptionState } from '@qc/config-schema';

export type Status = 'not_set_up' | 'paid' | 'due_soon' | 'due' | 'overdue' | 'paused';

/** Order on the home page: what needs attention first. */
export const STATUS_ORDER: readonly Status[] = ['overdue', 'paused', 'due', 'due_soon', 'paid', 'not_set_up'];

export const DUE_SOON_DAYS = 5;
export const GRACE_DAYS = 7;
export const EXTEND_DAYS = 7;

export interface SubscriptionDates {
  nextDueDate: string;
  extendedUntil: string | null;
  pausedAt: Date | null;
}

const IST_OFFSET_MS = 5.5 * 3600_000;

export const istToday = (now: Date): string => new Date(now.getTime() + IST_OFFSET_MS).toISOString().slice(0, 10);

const asDate = (day: string) => new Date(`${day}T00:00:00Z`);
const asDay = (date: Date) => date.toISOString().slice(0, 10);

export const addDays = (day: string, days: number): string => asDay(new Date(asDate(day).getTime() + days * 86_400_000));

/** Same due day, `months` later. Due days are 1–28, so the day exists in every month. */
export function addMonths(day: string, months: number, dueDay: number): string {
  const date = asDate(day);
  return asDay(new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, dueDay)));
}

/** First due date of a new subscription: the next due day strictly after `created`. */
export function firstDueDate(created: string, dueDay: number): string {
  const date = asDate(created);
  const thisMonth = asDay(new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), dueDay)));
  return thisMonth > created ? thisMonth : addMonths(thisMonth, 1, dueDay);
}

/** The day the shop counts as overdue (7 days after the due date, or the end of an extension). */
export function overdueFrom(sub: SubscriptionDates): string {
  const grace = addDays(sub.nextDueDate, GRACE_DAYS);
  return sub.extendedUntil && sub.extendedUntil > grace ? sub.extendedUntil : grace;
}

/** "Extend 7 days": 7 days past the later of the current overdue point and today. */
export function nextOverduePoint(sub: SubscriptionDates, today: string): string {
  const current = overdueFrom(sub);
  return addDays(current > today ? current : today, EXTEND_DAYS);
}

export function statusOf(sub: SubscriptionDates | null, today: string): Status {
  if (!sub) return 'not_set_up';
  if (sub.pausedAt) return 'paused';
  if (today < addDays(sub.nextDueDate, -DUE_SOON_DAYS)) return 'paid';
  if (today < sub.nextDueDate) return 'due_soon';
  if (today < overdueFrom(sub)) return 'due';
  return 'overdue';
}

/** What the shop's apps and the order service see (tenant runtime config `subscription`). */
export function appStateOf(status: Status, sub: (SubscriptionDates & { feePaise: number }) | null, payTo?: string): SubscriptionState {
  if (!sub || (status !== 'due' && status !== 'overdue' && status !== 'paused')) return { state: 'ok' };
  return {
    state: status === 'paused' ? 'paused' : 'due',
    amountPaise: sub.feePaise,
    dueDate: sub.nextDueDate,
    ...(payTo ? { payTo } : {}),
  };
}
