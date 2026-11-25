import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { AppError, hitLimit, type Logger, type RateLimitStore } from '@qc/common';
import type { Db } from '../../db.js';
import type { Mailer } from '../../mail/mailer.js';

const CODE_TTL_MS = 10 * 60_000;
const MAX_ATTEMPTS = 5;
const RESEND_AFTER_MS = 30_000;
export const SESSION_TTL_MS = 7 * 24 * 60 * 60_000;

export interface AuthDeps {
  db: Db;
  mailer: Mailer;
  limits: RateLimitStore;
  logger: Logger;
  secret: string;
  /** Lower-case emails allowed to log in. */
  admins: readonly string[];
  now?: () => Date;
}

export const normalizeEmail = (email: string) => email.trim().toLowerCase();
const sha256 = (value: string) => createHash('sha256').update(value).digest('hex');

/** Email + 6-digit code login for the platform owner; sessions are opaque tokens stored hashed. */
export function createAuthService({ db, mailer, limits, logger, secret, admins, now = () => new Date() }: AuthDeps) {
  const hashCode = (email: string, code: string) => createHmac('sha256', secret).update(`${email}:${code}`).digest('hex');

  return {
    /**
     * Sends a code when the email is an admin. Anyone else gets the same answer and no mail, so the
     * page does not reveal who is an admin. Throws LOGIN_TOO_MANY / LOGIN_TOO_SOON for admins.
     */
    async requestCode(rawEmail: string, ip: string): Promise<void> {
      const email = normalizeEmail(rawEmail);
      const at = now();
      const byIp = await hitLimit(limits, `platform:login:ip:${ip}`, 20, 3600, at.getTime());
      if (!byIp.allowed) throw new AppError('LOGIN_TOO_MANY', 429, 'Too many tries. Wait an hour and try again.');
      if (!admins.includes(email)) {
        logger.warn({ ip }, 'login code requested for an email that is not an admin');
        return;
      }
      const latest = await db.adminLoginCode.findFirst({ where: { email }, orderBy: { createdAt: 'desc' } });
      if (latest && at.getTime() - latest.createdAt.getTime() < RESEND_AFTER_MS) {
        throw new AppError('LOGIN_TOO_SOON', 429, 'A code was just sent. Wait 30 seconds before asking again.');
      }
      const byEmail = await hitLimit(limits, `platform:login:email:${email}`, 5, 3600, at.getTime());
      if (!byEmail.allowed) throw new AppError('LOGIN_TOO_MANY', 429, 'Too many codes. Wait an hour and try again.');

      const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
      await db.adminLoginCode.create({ data: { email, codeHash: hashCode(email, code), expiresAt: new Date(at.getTime() + CODE_TTL_MS), createdAt: at } });
      await mailer.send({
        to: email,
        subject: `Admin login code: ${code}`,
        text: `Your login code for the shop apps admin is ${code}.\nIt works for 10 minutes. If you did not ask for it, ignore this email.`,
      });
    },

    /** Checks the newest code for the email; returns a new session token. */
    async verifyCode(rawEmail: string, code: string): Promise<string> {
      const email = normalizeEmail(rawEmail);
      const at = now();
      const invalid = () => new AppError('LOGIN_CODE_INVALID', 400, 'That code is not right or has expired. Ask for a new one.');
      if (!admins.includes(email) || !/^\d{6}$/.test(code)) throw invalid();
      const latest = await db.adminLoginCode.findFirst({ where: { email }, orderBy: { createdAt: 'desc' } });
      if (!latest || latest.consumedAt || latest.expiresAt <= at) throw invalid();
      // Count the attempt before comparing, atomically, so parallel guesses cannot exceed the limit.
      const counted = await db.adminLoginCode.updateMany({
        where: { id: latest.id, attempts: { lt: MAX_ATTEMPTS }, consumedAt: null },
        data: { attempts: { increment: 1 } },
      });
      if (counted.count === 0) throw invalid();
      const expected = Buffer.from(latest.codeHash, 'hex');
      const given = Buffer.from(hashCode(email, code), 'hex');
      if (!timingSafeEqual(expected, given)) throw invalid();
      const used = await db.adminLoginCode.updateMany({ where: { id: latest.id, consumedAt: null }, data: { consumedAt: at } });
      if (used.count === 0) throw invalid();

      const token = randomBytes(32).toString('base64url');
      await db.adminSession.create({ data: { tokenHash: sha256(token), email, expiresAt: new Date(at.getTime() + SESSION_TTL_MS), createdAt: at } });
      return token;
    },

    /** The admin email for a session token, or null (expired, logged out, or no longer an admin). */
    async session(token: string | undefined): Promise<string | null> {
      if (!token) return null;
      const session = await db.adminSession.findUnique({ where: { tokenHash: sha256(token) } });
      const at = now();
      if (!session || session.expiresAt <= at || !admins.includes(session.email)) return null;
      if (at.getTime() - session.lastSeenAt.getTime() > 60_000) {
        await db.adminSession.update({ where: { id: session.id }, data: { lastSeenAt: at } });
      }
      return session.email;
    },

    async logout(token: string | undefined): Promise<void> {
      if (token) await db.adminSession.deleteMany({ where: { tokenHash: sha256(token) } });
    },
  };
}

export type AuthService = ReturnType<typeof createAuthService>;
