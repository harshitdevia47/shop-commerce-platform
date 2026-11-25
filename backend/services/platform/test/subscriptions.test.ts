import { createLogger } from '@qc/common';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { createSubscriptionsService } from '../src/modules/subscriptions/subscriptions.service.js';
import { FakeDirectory, SHOP_A, SHOP_B, cleanDb, db } from './helpers.js';

let directory: FakeDirectory;
let clock: { now: Date };
const service = () =>
  createSubscriptionsService({ db, directory, logger: createLogger('t', 'silent'), payTo: 'me@okaxis', now: () => clock.now });

beforeEach(async () => {
  await cleanDb();
  directory = new FakeDirectory();
  clock = { now: new Date('2026-11-25T05:00:00Z') };
});
afterAll(async () => {
  await cleanDb();
  await db.$disconnect();
});

describe('subscriptions', () => {
  it('sets up with the first due day after today; shops without one are not set up', async () => {
    const s = service();
    await s.setup(SHOP_A, { feePaise: 99_900, dueDay: 5 });
    const rows = await s.overview();
    expect(rows.find((r) => r.shop.id === SHOP_A)).toMatchObject({ status: 'paid', subscription: { nextDueDate: '2026-12-05', feePaise: 99_900 } });
    expect(rows.find((r) => r.shop.id === SHOP_B)).toMatchObject({ status: 'not_set_up', subscription: null });
    expect(directory.pushed.get(SHOP_A)).toEqual({ state: 'ok' });
  });

  it('mark paid moves the due date by the months covered, clears the extension, resumes, and pushes ok', async () => {
    const s = service();
    await s.setup(SHOP_A, { feePaise: 99_900, dueDay: 5 });
    clock.now = new Date('2026-12-15T05:00:00Z');
    expect((await s.get(SHOP_A)).status).toBe('overdue');
    await s.extend(SHOP_A);
    await s.pause(SHOP_A);
    expect(directory.pushed.get(SHOP_A)).toEqual({ state: 'paused', amountPaise: 99_900, dueDate: '2026-12-05', payTo: 'me@okaxis' });

    await s.markPaid(SHOP_A, { amountPaise: 199_800, upiRef: '123456789012', paidOn: '2026-12-15', months: 2, by: 'owner@example.com' });
    const after = await s.get(SHOP_A);
    expect(after.subscription).toMatchObject({ nextDueDate: '2027-02-05', extendedUntil: null, pausedAt: null });
    expect(after.status).toBe('paid');
    expect(after.payments).toEqual([expect.objectContaining({ amountPaise: 199_800, upiRef: '123456789012', months: 2, paidOn: '2026-12-15' })]);
    expect(directory.pushed.get(SHOP_A)).toEqual({ state: 'ok' });
  });

  it('a repeated form id is ignored', async () => {
    const s = service();
    await s.setup(SHOP_A, { feePaise: 99_900, dueDay: 5 });
    const payment = { amountPaise: 99_900, paidOn: '2026-11-25', months: 1, by: 'owner@example.com', formId: 'form-1' };
    expect(await s.markPaid(SHOP_A, payment)).toBe('done');
    expect(await s.markPaid(SHOP_A, payment)).toBe('repeat');
    const after = await s.get(SHOP_A);
    expect(after.payments).toHaveLength(1);
    expect(after.subscription!.nextDueDate).toBe('2027-01-05');
  });

  it('extend pushes the overdue point 7 days past the later of the current point and today', async () => {
    const s = service();
    await s.setup(SHOP_A, { feePaise: 50_000, dueDay: 5 });
    clock.now = new Date('2026-12-06T05:00:00Z');
    await s.extend(SHOP_A);
    expect((await s.get(SHOP_A)).subscription!.extendedUntil).toBe('2026-12-19');
    clock.now = new Date('2026-12-19T05:00:00Z');
    expect((await s.get(SHOP_A)).status).toBe('overdue');
    await s.extend(SHOP_A);
    expect((await s.get(SHOP_A)).subscription!.extendedUntil).toBe('2026-12-26');
    expect((await s.get(SHOP_A)).status).toBe('due');
  });

  it('edit changes fee and due day (same month), checklist ticks are saved', async () => {
    const s = service();
    await s.setup(SHOP_A, { feePaise: 50_000, dueDay: 5 });
    await s.edit(SHOP_A, { feePaise: 79_900, dueDay: 20 });
    expect((await s.get(SHOP_A)).subscription).toMatchObject({ feePaise: 79_900, dueDay: 20, nextDueDate: '2026-12-20' });
    await s.setChecklist(SHOP_A, { logoDone: true });
    expect((await s.get(SHOP_A)).subscription).toMatchObject({ logoDone: true, playDone: false });
  });

  it('refuses actions for shops without a subscription and setup twice', async () => {
    const s = service();
    await expect(s.pause(SHOP_B)).rejects.toMatchObject({ code: 'SUBSCRIPTION_NOT_FOUND' });
    await s.setup(SHOP_A, { feePaise: 50_000, dueDay: 5 });
    await expect(s.setup(SHOP_A, { feePaise: 50_000, dueDay: 5 })).rejects.toMatchObject({ code: 'SUBSCRIPTION_EXISTS' });
    await expect(s.setup('01936a00-0000-7000-8000-0000000000ff', { feePaise: 50_000, dueDay: 5 })).rejects.toMatchObject({ code: 'SHOP_NOT_FOUND' });
  });

  it('pushes every shop hourly; one failing shop does not stop the others', async () => {
    const s = service();
    await s.setup(SHOP_A, { feePaise: 50_000, dueDay: 5 });
    await s.setup(SHOP_B, { feePaise: 50_000, dueDay: 5 });
    directory.pushed.clear();
    directory.failPush.add(SHOP_A);
    clock.now = new Date('2026-12-06T05:00:00Z');
    const result = await s.pushAll();
    expect(result).toEqual({ pushed: 1, failed: 1 });
    expect(directory.pushed.get(SHOP_B)).toEqual({ state: 'due', amountPaise: 50_000, dueDate: '2026-12-05', payTo: 'me@okaxis' });
  });
});
