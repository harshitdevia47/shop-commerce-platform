import request from 'supertest';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { ADMIN, ORIGIN, buildApp, cleanDb, db, login, post, type TestApp } from './helpers.js';

let t: TestApp;
beforeEach(async () => {
  await cleanDb();
  t = buildApp();
});
afterAll(async () => {
  await cleanDb();
  await db.$disconnect();
});

describe('login with an emailed code', () => {
  it('emails a 6-digit code to an admin and logs in with it', async () => {
    const page = await post(t.app, '/login', { email: ' Owner@Example.com ' });
    expect(page.status).toBe(200);
    expect(page.text).toContain('Enter the code');
    expect(t.mailer.sent).toHaveLength(1);
    expect(t.mailer.sent[0]!.to).toBe(ADMIN);
    expect(t.mailer.lastCode()).toMatch(/^\d{6}$/);

    const res = await post(t.app, '/login/verify', { email: ADMIN, code: t.mailer.lastCode() });
    expect(res.status).toBe(303);
    expect(res.headers.location).toBe('/');
    const cookie = (res.headers['set-cookie'] as unknown as string[])[0]!;
    expect(cookie).toMatch(/^qc_admin=.+; Path=\/; HttpOnly; SameSite=Strict; Max-Age=604800$/);

    const home = await request(t.app).get('/').set('cookie', cookie.split(';')[0]!);
    expect(home.status).toBe(200);
    expect(home.text).toContain(ADMIN);
    expect(home.headers['content-security-policy']).toContain("default-src 'none'");
  });

  it('answers the same for an email that is not an admin, but sends nothing', async () => {
    const page = await post(t.app, '/login', { email: 'stranger@example.com' });
    expect(page.status).toBe(200);
    expect(page.text).toContain('Enter the code');
    expect(t.mailer.sent).toHaveLength(0);
    expect((await post(t.app, '/login/verify', { email: 'stranger@example.com', code: '123456' })).status).toBe(400);
  });

  it('refuses a wrong code, locks after 5 tries, and only the newest code works', async () => {
    await post(t.app, '/login', { email: ADMIN });
    const first = t.mailer.lastCode();
    t.clock.now = new Date(t.clock.now.getTime() + 31_000);
    await post(t.app, '/login', { email: ADMIN });
    const second = t.mailer.lastCode();
    if (first !== second) expect((await post(t.app, '/login/verify', { email: ADMIN, code: first })).status).toBe(400);

    const wrong = second === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) await post(t.app, '/login/verify', { email: ADMIN, code: wrong });
    const locked = await post(t.app, '/login/verify', { email: ADMIN, code: second });
    expect(locked.status).toBe(400);
    expect(locked.text).toContain('not right or has expired');
  });

  it('codes expire after 10 minutes and cannot be used twice', async () => {
    await post(t.app, '/login', { email: ADMIN });
    const code = t.mailer.lastCode();
    t.clock.now = new Date(t.clock.now.getTime() + 10 * 60_000 + 1);
    expect((await post(t.app, '/login/verify', { email: ADMIN, code })).status).toBe(400);

    t.clock.now = new Date(t.clock.now.getTime() + 60_000);
    await post(t.app, '/login', { email: ADMIN });
    const fresh = t.mailer.lastCode();
    expect((await post(t.app, '/login/verify', { email: ADMIN, code: fresh })).status).toBe(303);
    expect((await post(t.app, '/login/verify', { email: ADMIN, code: fresh })).status).toBe(400);
  });

  it('a new code needs 30 seconds', async () => {
    await post(t.app, '/login', { email: ADMIN });
    const again = await post(t.app, '/login', { email: ADMIN });
    expect(again.status).toBe(429);
    expect(again.text).toContain('Wait 30 seconds');
    expect(t.mailer.sent).toHaveLength(1);
  });
});

describe('sessions and protection', () => {
  it('pages need a session; logout ends it', async () => {
    expect((await request(t.app).get('/')).headers.location).toBe('/login');
    const cookie = await login(t);
    expect((await request(t.app).get('/').set('cookie', cookie)).status).toBe(200);
    const out = await post(t.app, '/logout', {}, cookie);
    expect(out.status).toBe(303);
    expect((await request(t.app).get('/').set('cookie', cookie)).status).toBe(303);
  });

  it('sessions end after 7 days', async () => {
    const cookie = await login(t);
    t.clock.now = new Date(t.clock.now.getTime() + 7 * 24 * 3600_000 + 1);
    expect((await request(t.app).get('/').set('cookie', cookie)).status).toBe(303);
  });

  it('refuses form posts from another site or without an Origin', async () => {
    const cookie = await login(t);
    expect((await request(t.app).post('/logout').set('cookie', cookie).set('origin', 'https://evil.example').type('form').send({})).status).toBe(403);
    expect((await request(t.app).post('/login').type('form').send({ email: ADMIN })).status).toBe(403);
    expect((await request(t.app).post('/logout').set('origin', ORIGIN).type('form').send({})).status).toBe(303);
  });

  it('health is open', async () => {
    expect((await request(t.app).get('/health')).status).toBe(200);
  });
});
