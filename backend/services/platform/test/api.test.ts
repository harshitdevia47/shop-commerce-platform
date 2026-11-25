import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { ADMIN, SHOP_A, SHOP_B, api, buildApp, cleanDb, db, login } from './helpers.js';

let t: ReturnType<typeof buildApp>;
beforeEach(async () => {
  await cleanDb();
  t = buildApp();
});
afterAll(async () => {
  await cleanDb();
  await db.$disconnect();
});

const code = (email: string) => api(t.app, 'post', '/api/admin/login/code', undefined, { email });
const verify = (email: string, c: string) => api(t.app, 'post', '/api/admin/login/verify', undefined, { email, code: c });

describe('login', () => {
  it('emails a code to an admin and gives the app a token', async () => {
    expect((await code(' Owner@Example.com ')).body.data).toEqual({ sent: true });
    expect(t.mailer.sent).toHaveLength(1);
    const res = await verify(ADMIN, t.mailer.lastCode());
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ token: expect.any(String), email: ADMIN });
    expect((await api(t.app, 'get', '/api/admin/overview', res.body.data.token)).status).toBe(200);
  });

  it('answers the same for other emails but sends nothing', async () => {
    expect((await code('stranger@example.com')).body.data).toEqual({ sent: true });
    expect(t.mailer.sent).toHaveLength(0);
    expect((await verify('stranger@example.com', '123456')).body.error.code).toBe('LOGIN_CODE_INVALID');
  });

  it('locks after 5 wrong tries; codes expire; only the newest works; 30 s between codes', async () => {
    await code(ADMIN);
    expect((await code(ADMIN)).body.error.code).toBe('LOGIN_TOO_SOON');
    const first = t.mailer.lastCode();
    t.clock.now = new Date(t.clock.now.getTime() + 31_000);
    await code(ADMIN);
    const second = t.mailer.lastCode();
    if (first !== second) expect((await verify(ADMIN, first)).status).toBe(400);
    const wrong = second === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) await verify(ADMIN, wrong);
    expect((await verify(ADMIN, second)).status).toBe(400);

    t.clock.now = new Date(t.clock.now.getTime() + 60_000);
    await code(ADMIN);
    const late = t.mailer.lastCode();
    t.clock.now = new Date(t.clock.now.getTime() + 10 * 60_000 + 1);
    expect((await verify(ADMIN, late)).status).toBe(400);
  });
});

describe('sessions', () => {
  it('every admin route needs a token', async () => {
    for (const [method, path] of [
      ['get', '/api/admin/overview'],
      ['get', `/api/admin/shops/${SHOP_A}`],
      ['post', `/api/admin/shops/${SHOP_A}/pause`],
      ['put', '/api/admin/device'],
    ] as const) {
      const res = await api(t.app, method, path, undefined, {});
      expect(res.status, path).toBe(401);
      expect(res.body.error.code).toBe('ADMIN_AUTH_REQUIRED');
    }
  });

  it('lasts 90 days, renewed while used', async () => {
    const token = await login(t);
    t.clock.now = new Date(t.clock.now.getTime() + 80 * 86_400_000);
    expect((await api(t.app, 'get', '/api/admin/overview', token)).status).toBe(200); // renews
    t.clock.now = new Date(t.clock.now.getTime() + 80 * 86_400_000);
    expect((await api(t.app, 'get', '/api/admin/overview', token)).status).toBe(200);
    t.clock.now = new Date(t.clock.now.getTime() + 91 * 86_400_000);
    expect((await api(t.app, 'get', '/api/admin/overview', token)).status).toBe(401);
  });

  it('registers the phone for notifications; logout removes session and phone', async () => {
    const token = await login(t);
    const fcm = 'fcm-token-'.padEnd(40, 'x');
    expect((await api(t.app, 'put', '/api/admin/device', token, { token: fcm, platform: 'android' })).status).toBe(204);
    expect(await db.adminDevice.findMany()).toEqual([expect.objectContaining({ token: fcm, email: ADMIN })]);
    expect((await api(t.app, 'post', '/api/admin/logout', token)).status).toBe(204);
    expect(await db.adminDevice.count()).toBe(0);
    expect((await api(t.app, 'get', '/api/admin/overview', token)).status).toBe(401);
  });
});

describe('shops', () => {
  let token: string;
  const act = (name: string, body: object = {}, shop = SHOP_A) => api(t.app, 'post', `/api/admin/shops/${shop}/${name}`, token, body);
  beforeEach(async () => {
    token = await login(t);
  });

  it('overview: rows by what needs attention, counts and numbers', async () => {
    t.directory.shops.push({ ...t.directory.shops[0]!, id: '01936a00-0000-7000-8000-00000000000c', slug: 'late_shop', name: 'Late Shop' });
    await act('setup', { feeRupees: '999', dueDay: 5 });
    await act('setup', { feeRupees: 500, dueDay: 1 }, '01936a00-0000-7000-8000-00000000000c');
    t.clock.now = new Date('2026-12-09T05:00:00Z');
    t.directory.numbersFor[SHOP_A] = { customers: { total: 312, newSince: 40, activeSince: 120 }, owner: null, products: 50, month: { orders: 87, salesPaise: 4_500_000, lastOrderAt: null } };
    const res = await api(t.app, 'get', '/api/admin/overview', token);
    expect(res.body.data.rows.map((r: { shop: { name: string }; status: string }) => [r.shop.name, r.status])).toEqual([
      ['Late Shop', 'overdue'],
      ['Sharma Kirana', 'due'],
      ['Style Hub', 'not_set_up'],
    ]);
    expect(res.body.data.counts).toMatchObject({ overdue: 1, due: 1, not_set_up: 1, paid: 0 });
    expect(res.body.data.rows[1].numbers.customers.total).toBe(312);
  });

  it('shop actions: setup, pause, mark paid, extend, edit, checklist', async () => {
    let res = await act('setup', { feeRupees: '999', dueDay: 5, formId: 'form-0001' });
    expect(res.body.data.result).toBe('done');
    expect(res.body.data.shop).toMatchObject({ status: 'paid', subscription: { feePaise: 99_900, nextDueDate: '2026-12-05' }, payTo: 'me@okaxis', defaultFeeRupees: 999 });

    res = await act('pause', { formId: 'form-0002' });
    expect(res.body.data.shop.status).toBe('paused');
    expect(t.directory.pushed.get(SHOP_A)).toMatchObject({ state: 'paused' });

    res = await act('paid', { amountRupees: '1,998', months: 2, upiRef: '4321', paidOn: '2026-11-26', note: 'two months', formId: 'form-0003' });
    expect(res.body.data.shop).toMatchObject({ status: 'paid', subscription: { nextDueDate: '2027-02-05', pausedAt: null } });
    expect(res.body.data.shop.payments).toEqual([expect.objectContaining({ amountPaise: 199_800, months: 2, upiRef: '4321', note: 'two months', recordedBy: ADMIN })]);
    expect((await act('paid', { amountRupees: '1,998', months: 2, paidOn: '2026-11-26', formId: 'form-0003' })).body.data.result).toBe('repeat');

    expect((await act('extend', { formId: 'form-0004' })).body.data.shop.subscription.extendedUntil).not.toBeNull();
    expect((await act('edit', { feeRupees: 799, dueDay: 20 })).body.data.shop.subscription).toMatchObject({ feePaise: 79_900, dueDay: 20 });
    expect((await act('checklist', { logoDone: true, playDone: false })).body.data.shop.subscription).toMatchObject({ logoDone: true, playDone: false });
  });

  it('explains wrong values and refuses unknown shops', async () => {
    const bad = await act('setup', { feeRupees: 'abc', dueDay: 31 });
    expect(bad.status).toBe(400);
    expect(bad.body.error.code).toBe('VALIDATION_FAILED');
    expect(JSON.stringify(bad.body.error.details)).toContain('Monthly fee: enter an amount in rupees');
    expect(JSON.stringify(bad.body.error.details)).toContain('Due day: from 1 to 28');
    expect((await act('pause', {}, '01936a00-0000-7000-8000-0000000000ff')).status).toBe(404);
    expect((await api(t.app, 'get', '/api/admin/shops/not-a-uuid', token)).status).toBe(400);
    expect((await act('pause', {}, SHOP_B)).body.error.code).toBe('SUBSCRIPTION_NOT_FOUND');
    await act('setup', { feeRupees: 1, dueDay: 1 });
    expect((await act('setup', { feeRupees: 1, dueDay: 1 })).body.error.code).toBe('SUBSCRIPTION_EXISTS');
  });

  it('shop detail has the numbers and the shop contact', async () => {
    const res = await api(t.app, 'get', `/api/admin/shops/${SHOP_A}`, token);
    expect(res.body.data).toMatchObject({ shop: { name: 'Sharma Kirana', contact: { phone: '+919876543210' } }, subscription: null, status: 'not_set_up', today: '2026-11-26', payments: [] });
  });
});
