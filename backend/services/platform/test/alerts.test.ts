import { createLogger } from '@qc/common';
import type { PushMessage, PushSender } from '@qc/fcm';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { runDailyAlerts } from '../src/jobs/daily-alerts.js';
import { createSubscriptionsService } from '../src/modules/subscriptions/subscriptions.service.js';
import { CapturingMailer, FakeDirectory, SHOP_A, SHOP_B, cleanDb, db } from './helpers.js';

let directory: FakeDirectory;
let mailer: CapturingMailer;
let clock: { now: Date };
const subs = () => createSubscriptionsService({ db, directory, logger: createLogger('t', 'silent'), now: () => clock.now });
const run = (push: PushSender | null = null) =>
  runDailyAlerts({ db, push, mailer, directory, logger: createLogger('t', 'silent'), now: () => clock.now, to: 'owner@example.com' });
/** IST wall clock → instant. */
const at = (ist: string) => new Date(`${ist}+05:30`);

beforeEach(async () => {
  await cleanDb();
  directory = new FakeDirectory();
  mailer = new CapturingMailer();
  clock = { now: at('2026-11-25T10:00:00') };
  await subs().setup(SHOP_A, { feePaise: 99_900, dueDay: 5 }); // due 5 Dec, overdue from 12 Dec
  await subs().setup(SHOP_B, { feePaise: 50_000, dueDay: 5 });
});
afterAll(async () => {
  await cleanDb();
  await db.$disconnect();
});

describe('daily overdue email', () => {
  it('waits until 9:00 IST, then mails newly overdue shops once', async () => {
    clock.now = at('2026-12-12T08:59:00');
    expect(await run()).toEqual({ sent: false, shops: 0, via: null });
    clock.now = at('2026-12-12T09:00:00');
    expect(await run()).toEqual({ sent: true, shops: 2, via: 'email' });
    expect(mailer.sent).toHaveLength(1);
    const mail = mailer.sent[0]!;
    expect(mail.to).toBe('owner@example.com');
    expect(mail.subject).toBe('2 shops need attention');
    expect(mail.text).toContain('Sharma Kirana is 7 days overdue: ₹999 since 5 Dec 2026');

    clock.now = at('2026-12-12T15:00:00');
    expect((await run()).sent).toBe(false);
    clock.now = at('2026-12-13T09:15:00');
    expect((await run()).sent).toBe(false); // still overdue, nothing new
    expect(mailer.sent).toHaveLength(1);
  });

  it('mails again when an extension ends; paused and not-set-up shops are never listed', async () => {
    clock.now = at('2026-12-12T09:00:00');
    await run();
    await subs().pause(SHOP_B);
    await subs().extend(SHOP_A); // overdue point 12 Dec → 19 Dec
    clock.now = at('2026-12-19T09:30:00');
    expect(await run()).toEqual({ sent: true, shops: 1, via: 'email' });
    expect(mailer.sent[1]!.subject).toBe('Sharma Kirana: the extra 7 days are over');
    expect(mailer.sent[1]!.text).not.toContain('Style Hub');
  });

  it('a failed mail is retried on the next run', async () => {
    clock.now = at('2026-12-12T09:00:00');
    const failing = { send: async () => { throw new Error('smtp down'); } };
    await expect(runDailyAlerts({ db, push: null, mailer: failing, directory, logger: createLogger('t', 'silent'), now: () => clock.now, to: 'x@example.com' })).rejects.toThrow('smtp down');
    clock.now = at('2026-12-12T09:15:00');
    expect((await run()).shops).toBe(2);
  });

  it('sends phone notifications to registered admin phones instead of email; gone phones are removed', async () => {
    const session = await db.adminSession.create({ data: { tokenHash: 'h1', email: 'owner@example.com', expiresAt: at('2027-06-01T00:00:00') } });
    await db.adminDevice.createMany({ data: [
      { sessionId: session.id, email: 'owner@example.com', token: 'phone-ok', platform: 'android' },
      { sessionId: session.id, email: 'owner@example.com', token: 'phone-gone', platform: 'android' },
    ] });
    const sent: PushMessage[] = [];
    const push: PushSender = {
      name: 'fake',
      async send(messages) {
        sent.push(...messages);
        return { sent: messages.filter((m) => m.token === 'phone-ok').length, invalidTokens: ['phone-gone'] };
      },
    };
    clock.now = at('2026-12-12T09:00:00');
    expect(await run(push)).toEqual({ sent: true, shops: 2, via: 'push' });
    expect(mailer.sent).toHaveLength(0);
    expect(sent.filter((m) => m.token === 'phone-ok')).toEqual([
      expect.objectContaining({ title: 'Sharma Kirana is 7 days overdue', body: '₹999 since 5 Dec 2026', data: { shopId: SHOP_A }, channelId: 'alerts' }),
      expect.objectContaining({ title: 'Style Hub is 7 days overdue', data: { shopId: SHOP_B } }),
    ]);
    expect((await db.adminDevice.findMany()).map((d) => d.token)).toEqual(['phone-ok']);
  });

  it('falls back to email when no phone took the notification', async () => {
    const push: PushSender = { name: 'fake', send: async () => ({ sent: 0, invalidTokens: [] }) };
    const session = await db.adminSession.create({ data: { tokenHash: 'h2', email: 'owner@example.com', expiresAt: at('2027-06-01T00:00:00') } });
    await db.adminDevice.create({ data: { sessionId: session.id, email: 'owner@example.com', token: 'phone-x', platform: 'android' } });
    clock.now = at('2026-12-12T09:00:00');
    expect((await run(push)).via).toBe('email');
    expect(mailer.sent).toHaveLength(1);
  });
});
