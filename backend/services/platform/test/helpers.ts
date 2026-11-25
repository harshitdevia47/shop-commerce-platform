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
