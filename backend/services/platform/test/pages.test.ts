import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { SHOP_A, SHOP_B, buildApp, cleanDb, db, login, post } from './helpers.js';

let t: ReturnType<typeof buildApp>;
let cookie: string;
const get = (path: string) => request(t.app).get(path).set('cookie', cookie);
const send = (path: string, form: Record<string, string> = {}) => post(t.app, path, form, cookie);

beforeEach(async () => {
  await cleanDb();
  t = buildApp();
  cookie = await login(t);
});
afterAll(async () => {
  await cleanDb();
  await db.$disconnect();
});

describe('home', () => {
  it('lists shops by what needs attention, with count tiles', async () => {
    t.directory.shops.push({ ...t.directory.shops[0]!, id: '01936a00-0000-7000-8000-00000000000c', slug: 'late_shop', name: 'Late Shop' });
    await send(`/shops/${SHOP_A}/setup`, { fee: '999', dueDay: '5' }).expect(303);
    await send('/shops/01936a00-0000-7000-8000-00000000000c/setup', { fee: '500', dueDay: '1' }).expect(303);
    t.clock.now = new Date('2026-12-09T05:00:00Z'); // Late Shop: due 1 Dec → overdue; Sharma: due 5 Dec → due
    cookie = await login(t); // the first session ended after 7 days
    t.directory.numbersFor[SHOP_A] = { customers: { total: 312, newSince: 40, activeSince: 120 }, owner: null, products: 50, month: { orders: 87, salesPaise: 4_500_000, lastOrderAt: '2026-12-08T10:00:00Z' } };

    const res = await get('/');
    expect(res.status).toBe(200);
    const order = ['Late Shop', 'Sharma Kirana', 'Style Hub'].map((name) => res.text.indexOf(name));
    expect(order).toEqual([...order].sort((a, b) => a - b));
    expect(res.text).toContain('312 customers · 87 orders this month');
    expect(res.text).toContain('Not set up');
    expect(res.text).toMatch(/Overdue<\/span><b>1<\/b>/);
    expect(res.text).toMatch(/Due<\/span><b>1<\/b>/);
  });

  it('escapes shop names', async () => {
    t.directory.shops[0]!.name = '<b>x</b>';
    const res = await get('/');
    expect(res.text).toContain('&lt;b&gt;x&lt;/b&gt;');
    expect(res.text).not.toContain('<b>x</b>');
  });
});

describe('shop page actions', () => {
  it('sets up, marks paid, extends, pauses with confirmation and resumes', async () => {
    const setup = await send(`/shops/${SHOP_A}/setup`, { fee: '999', dueDay: '5', formId: 'f1' });
    expect(setup.headers.location).toBe(`/shops/${SHOP_A}?done=setup`);
    let page = await get(`/shops/${SHOP_A}?done=setup`);
    expect(page.text).toContain('Subscription set up.');
    expect(page.text).toContain('₹999');
    expect(page.text).toContain('5 Dec 2026');

    expect((await get(`/shops/${SHOP_A}/pause`)).text).toContain('Pause online orders?');
    await send(`/shops/${SHOP_A}/pause`, { formId: 'f2' }).expect(303);
    expect(t.directory.pushed.get(SHOP_A)).toMatchObject({ state: 'paused' });
    expect((await get(`/shops/${SHOP_A}`)).text).toContain('Resume orders');

    await send(`/shops/${SHOP_A}/paid`, { amount: '999', months: '1', upiRef: '4321', paidOn: '2026-11-26', note: 'cash at shop', formId: 'f3' }).expect(303);
    page = await get(`/shops/${SHOP_A}`);
    expect(page.text).toContain('5 Jan 2027');
    expect(page.text).toContain('4321');
    expect(page.text).toContain('cash at shop');
    expect(t.directory.pushed.get(SHOP_A)).toEqual({ state: 'ok' });

    await send(`/shops/${SHOP_A}/extend`, { formId: 'f4' }).expect(303);
    expect((await get(`/shops/${SHOP_A}`)).text).toContain('Extended until');
  });

  it('ignores a repeated form and shows that nothing changed', async () => {
    await send(`/shops/${SHOP_A}/setup`, { fee: '999', dueDay: '5' });
    const form = { amount: '999', months: '1', paidOn: '2026-11-26', formId: 'same' };
    await send(`/shops/${SHOP_A}/paid`, form).expect(303);
    const again = await send(`/shops/${SHOP_A}/paid`, form);
    expect(again.headers.location).toBe(`/shops/${SHOP_A}?done=repeat`);
    expect((await db.subscriptionPayment.count())).toBe(1);
  });

  it('shows form mistakes on the page', async () => {
    const bad = await send(`/shops/${SHOP_A}/setup`, { fee: 'abc', dueDay: '31' });
    expect(bad.status).toBe(400);
    expect(bad.text).toContain('Monthly fee: enter an amount in rupees');
    expect(await db.subscription.count()).toBe(0);
  });

  it('checklist ticks, WhatsApp reminder, unknown shop 404', async () => {
    await send(`/shops/${SHOP_A}/setup`, { fee: '999', dueDay: '5' });
    await send(`/shops/${SHOP_A}/checklist`, { logoDone: '1', sent: '1' }).expect(303);
    const page = await get(`/shops/${SHOP_A}`);
    expect(page.text).toMatch(/name="logoDone" value="1" checked/);
    expect(page.text).toContain('https://wa.me/919876543210?text=');
    expect(page.text).toContain(encodeURIComponent('me@okaxis'));
    expect((await get('/shops/01936a00-0000-7000-8000-0000000000ff')).status).toBe(404);
    expect((await get('/shops/not-an-id')).status).toBe(404);
  });

  it('every page and action needs a session', async () => {
    expect((await request(t.app).get(`/shops/${SHOP_B}`)).status).toBe(303);
    expect((await post(t.app, `/shops/${SHOP_B}/setup`, { fee: '1', dueDay: '1' })).status).toBe(401);
  });
});
