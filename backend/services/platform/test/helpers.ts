import { MemoryRateLimitStore, createLogger } from '@qc/common';
import request from 'supertest';
import type { Express } from 'express';
import { createPlatformApp, type PlatformAppDeps } from '../src/app.js';
import { createDb } from '../src/db.js';
import type { MailMessage, Mailer } from '../src/mail/mailer.js';

export const db = createDb(process.env.DATABASE_URL!);
export const ADMIN = 'owner@example.com';
export const ORIGIN = 'http://admin.test';

export class CapturingMailer implements Mailer {
  sent: MailMessage[] = [];
  async send(message: MailMessage): Promise<void> {
    this.sent.push(message);
  }
  lastCode(): string {
    const subject = this.sent.at(-1)?.subject ?? '';
    return /(\d{6})/.exec(subject)?.[1] ?? '';
  }
}

export interface TestApp {
  app: Express;
  mailer: CapturingMailer;
  clock: { now: Date };
}

export function buildApp(extra: Partial<PlatformAppDeps> = {}): TestApp {
  const mailer = new CapturingMailer();
  const clock = { now: new Date('2026-11-26T04:30:00Z') };
  const app = createPlatformApp({
    db,
    logger: createLogger('platform-test', 'silent'),
    mailer,
    limits: new MemoryRateLimitStore(() => clock.now.getTime()),
    loginCodeSecret: 'test-login-code-secret-test-login-code-secret',
    admins: [ADMIN],
    origin: ORIGIN,
    cookie: { secure: false },
    now: () => clock.now,
    ...extra,
  });
  return { app, mailer, clock };
}

/** Posts a form the way a browser on the admin site does. */
export const post = (app: Express, path: string, form: Record<string, string>, cookie?: string) => {
  const req = request(app).post(path).set('origin', ORIGIN).type('form').send(form);
  return cookie ? req.set('cookie', cookie) : req;
};

/** Logs the admin in and returns the session cookie. */
export async function login(t: TestApp): Promise<string> {
  await post(t.app, '/login', { email: ADMIN }).expect(200);
  const res = await post(t.app, '/login/verify', { email: ADMIN, code: t.mailer.lastCode() }).expect(303);
  return (res.headers['set-cookie'] as unknown as string[])[0]!.split(';')[0]!;
}

export async function cleanDb(): Promise<void> {
  await db.subscriptionPayment.deleteMany();
  await db.subscription.deleteMany();
  await db.alertLog.deleteMany();
  await db.usedForm.deleteMany();
  await db.dailyMail.deleteMany();
  await db.adminSession.deleteMany();
  await db.adminLoginCode.deleteMany();
}

import type { SubscriptionState } from '@qc/config-schema';
import type { ShopDirectory, ShopNumbers, ShopSummary } from '../src/modules/subscriptions/shop-directory.js';

export const SHOP_A = '01936a00-0000-7000-8000-00000000000a';
export const SHOP_B = '01936a00-0000-7000-8000-00000000000b';

/** In-memory stand-in for the other services. */
export class FakeDirectory implements ShopDirectory {
  shops: ShopSummary[] = [
    { id: SHOP_A, slug: 'sharma_kirana', name: 'Sharma Kirana', businessType: 'grocery', contact: { phone: '+919876543210', address: 'Station Road' }, isActive: true, createdAt: '2026-11-01T05:00:00.000Z' },
    { id: SHOP_B, slug: 'style_hub', name: 'Style Hub', businessType: 'clothing', contact: { phone: '+919811111111', address: 'Main Bazaar' }, isActive: true, createdAt: '2026-11-02T05:00:00.000Z' },
  ];
  pushed = new Map<string, SubscriptionState>();
  failPush = new Set<string>();
  synced: unknown[] = [];
  owners: { shopId: string; phone: string; name?: string }[] = [];
  numbersFor: Record<string, ShopNumbers> = {};

  async list() {
    return this.shops;
  }
  async numbers(shopId: string): Promise<ShopNumbers> {
    return this.numbersFor[shopId] ?? { customers: { total: 0, newSince: 0, activeSince: 0 }, owner: { name: null, phone: null, hasLoggedIn: false }, products: 0, month: { orders: 0, salesPaise: 0, lastOrderAt: null } };
  }
  async pushState(shopId: string, state: SubscriptionState) {
    if (this.failPush.has(shopId)) throw new Error('tenant down');
    this.pushed.set(shopId, state);
  }
  async sync(clientJson: unknown) {
    this.synced.push(clientJson);
    const slug = (clientJson as { slug: string }).slug;
    const existing = this.shops.find((s) => s.slug === slug);
    if (existing) return { id: existing.id, slug, created: false };
    const id = `01936a00-0000-7000-8000-${String(this.shops.length).padStart(12, '0')}`;
    this.shops.push({ id, slug, name: slug, businessType: 'grocery', contact: { phone: '+919800000000', address: 'x' }, isActive: true, createdAt: new Date().toISOString() });
    return { id, slug, created: true };
  }
  async createOwner(shopId: string, phone: string, name?: string) {
    this.owners.push({ shopId, phone, ...(name ? { name } : {}) });
  }
}
