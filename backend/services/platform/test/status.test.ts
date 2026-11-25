import { describe, expect, it } from 'vitest';
import { addDays, addMonths, appStateOf, firstDueDate, istToday, nextOverduePoint, statusOf } from '../src/modules/subscriptions/status.js';

const sub = (over: Partial<{ nextDueDate: string; extendedUntil: string | null; pausedAt: Date | null; feePaise: number }> = {}) => ({
  nextDueDate: '2026-12-05',
  extendedUntil: null,
  pausedAt: null,
  feePaise: 99_900,
  ...over,
});

describe('status rules', () => {
  it.each([
    ['2026-11-29', 'paid'],
    ['2026-11-30', 'due_soon'],
    ['2026-12-04', 'due_soon'],
    ['2026-12-05', 'due'],
    ['2026-12-11', 'due'],
    ['2026-12-12', 'overdue'],
    ['2027-02-01', 'overdue'],
  ])('on %s the shop is %s', (today, status) => {
    expect(statusOf(sub(), today)).toBe(status);
  });

  it('an extension moves the overdue point; pause wins; no subscription = not set up', () => {
    expect(statusOf(sub({ extendedUntil: '2026-12-19' }), '2026-12-18')).toBe('due');
    expect(statusOf(sub({ extendedUntil: '2026-12-19' }), '2026-12-19')).toBe('overdue');
    expect(statusOf(sub({ pausedAt: new Date() }), '2026-11-01')).toBe('paused');
    expect(statusOf(null, '2026-11-01')).toBe('not_set_up');
  });

  it('next overdue point after an extension is 7 days past the later of the current point and today', () => {
    expect(nextOverduePoint(sub(), '2026-12-06')).toBe('2026-12-19');
    expect(nextOverduePoint(sub({ extendedUntil: '2026-12-19' }), '2026-12-10')).toBe('2026-12-26');
    expect(nextOverduePoint(sub(), '2026-12-30')).toBe('2027-01-06');
  });
});

describe('dates', () => {
  it('adds months keeping the due day', () => {
    expect(addMonths('2026-01-28', 1, 28)).toBe('2026-02-28');
    expect(addMonths('2026-11-05', 3, 5)).toBe('2027-02-05');
    expect(addMonths('2026-12-05', 1, 5)).toBe('2027-01-05');
  });

  it('first due date is the next due day after creation', () => {
    expect(firstDueDate('2026-11-25', 5)).toBe('2026-12-05');
    expect(firstDueDate('2026-11-05', 5)).toBe('2026-12-05');
    expect(firstDueDate('2026-11-04', 5)).toBe('2026-11-05');
    expect(firstDueDate('2026-12-31', 1)).toBe('2027-01-01');
  });

  it('today is the IST calendar day; addDays crosses months', () => {
    expect(istToday(new Date('2026-11-25T18:29:00Z'))).toBe('2026-11-25');
    expect(istToday(new Date('2026-11-25T18:31:00Z'))).toBe('2026-11-26');
    expect(addDays('2026-11-28', 5)).toBe('2026-12-03');
  });
});

describe('what the apps see', () => {
  it('maps statuses to app states with the amount, date and UPI ID', () => {
    const s = sub();
    expect(appStateOf('paid', s, 'me@okaxis')).toEqual({ state: 'ok' });
    expect(appStateOf('due_soon', s, 'me@okaxis')).toEqual({ state: 'ok' });
    expect(appStateOf('not_set_up', null)).toEqual({ state: 'ok' });
    expect(appStateOf('due', s, 'me@okaxis')).toEqual({ state: 'due', amountPaise: 99_900, dueDate: '2026-12-05', payTo: 'me@okaxis' });
    expect(appStateOf('overdue', s)).toEqual({ state: 'due', amountPaise: 99_900, dueDate: '2026-12-05' });
    expect(appStateOf('paused', s, 'me@okaxis')).toEqual({ state: 'paused', amountPaise: 99_900, dueDate: '2026-12-05', payTo: 'me@okaxis' });
  });
});
