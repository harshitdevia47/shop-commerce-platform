import { createHmac, randomInt, timingSafeEqual } from 'node:crypto';
import { AppError, getContext, hitLimit, requireShopId, type Logger, type RateLimitStore } from '@qc/common';
import type { Db } from '../../db.js';
import type { SmsProvider } from '../../sms/sms-provider.js';

export const OTP_LENGTH = 6;
export const OTP_TTL_SECONDS = 5 * 60;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_RESEND_COOLDOWN_SECONDS = 30;
export const OTP_MAX_PER_PHONE_PER_HOUR = 5;
export const OTP_MAX_PER_IP_PER_HOUR = 20;

export interface OtpServiceOptions {
  db: Db;
  sms: SmsProvider;
  limits: RateLimitStore;
  secret: string;
  logger: Logger;
  /** Dev only: return the code in the response. */
  devEcho?: boolean;
  now?: () => Date;
}

export interface OtpRequestResult {
  expiresInSeconds: number;
  resendAfterSeconds: number;
  /** Where the code was sent. */
  channel: 'sms' | 'whatsapp';
  /** Present only when OTP_DEV_ECHO is on (never in production). */
  debugCode?: string;
}

export function createOtpService(options: OtpServiceOptions) {
  const { db, sms, limits, secret, logger } = options;
  const now = options.now ?? (() => new Date());

  const hashCode = (shopId: string, phone: string, code: string): Buffer =>
    createHmac('sha256', secret).update(`${shopId}|${phone}|${code}`).digest();

  async function enforceRequestLimits(shopId: string, phone: string): Promise<void> {
    const nowMs = now().getTime();
    // True cooldown: the key's TTL is set on the first hit only.
    const recent = await limits.hit(`otp:cooldown:${shopId}:${phone}`, OTP_RESEND_COOLDOWN_SECONDS);
    if (recent > 1) {
      throw new AppError('OTP_RESEND_TOO_SOON', 429, 'Please wait before requesting another code', {
        retryAfterSeconds: OTP_RESEND_COOLDOWN_SECONDS,
      });
    }
    const perPhone = await hitLimit(limits, `otp:phone:${shopId}:${phone}`, OTP_MAX_PER_PHONE_PER_HOUR, 3600, nowMs);
    if (!perPhone.allowed) {
      throw new AppError('OTP_TOO_MANY_REQUESTS', 429, 'Too many codes requested, try again later', {
        retryAfterSeconds: perPhone.retryAfterSeconds,
      });
    }
    const ip = getContext()?.clientIp;
    if (ip) {
      const perIp = await hitLimit(limits, `otp:ip:${ip}`, OTP_MAX_PER_IP_PER_HOUR, 3600, nowMs);
      if (!perIp.allowed) {
        throw new AppError('OTP_TOO_MANY_REQUESTS', 429, 'Too many codes requested, try again later', {
          retryAfterSeconds: perIp.retryAfterSeconds,
        });
      }
    }
  }

  return {
    async request(phone: string, locale?: string): Promise<OtpRequestResult> {
      const shopId = requireShopId();
      await enforceRequestLimits(shopId, phone);

      const code = randomInt(0, 10 ** OTP_LENGTH).toString().padStart(OTP_LENGTH, '0');
      const issuedAt = now();

      // Only the newest code is valid.
      await db.otpChallenge.updateMany({
        where: { phone, consumedAt: null, expiresAt: { gt: issuedAt } },
        data: { expiresAt: issuedAt },
      });
      const challenge = await db.otpChallenge.create({
        data: {
          shopId,
          phone,
          codeHash: hashCode(shopId, phone, code).toString('hex'),
          expiresAt: new Date(issuedAt.getTime() + OTP_TTL_SECONDS * 1000),
          requestIp: getContext()?.clientIp,
        },
      });

      try {
        await sms.sendOtp({ phone, code, ...(locale ? { locale } : {}) });
      } catch (err) {
        await db.otpChallenge.update({ where: { id: challenge.id }, data: { expiresAt: issuedAt } });
        logger.error({ err, provider: sms.name }, 'OTP SMS failed');
        throw new AppError('SMS_SEND_FAILED', 503, 'Could not send the code, please try again');
      }

      return {
        expiresInSeconds: OTP_TTL_SECONDS,
        resendAfterSeconds: OTP_RESEND_COOLDOWN_SECONDS,
        channel: sms.channel,
        ...(options.devEcho ? { debugCode: code } : {}),
      };
    },

    /** Consumes the latest valid code for the phone. Throws on mismatch/expiry. */
    async verify(phone: string, code: string): Promise<void> {
      const shopId = requireShopId();
      const challenge = await db.otpChallenge.findFirst({
        where: { phone, consumedAt: null, expiresAt: { gt: now() } },
        orderBy: { createdAt: 'desc' },
      });
      if (!challenge) throw new AppError('OTP_EXPIRED', 400, 'Code expired, request a new one');

      // Count the attempt before comparing, atomically, so parallel guesses cannot exceed the limit.
      const counted = await db.otpChallenge.updateMany({
        where: { id: challenge.id, attempts: { lt: OTP_MAX_ATTEMPTS } },
        data: { attempts: { increment: 1 } },
      });
      if (counted.count === 0) {
        throw new AppError('OTP_TOO_MANY_ATTEMPTS', 429, 'Too many wrong attempts, request a new code');
      }

      const expected = Buffer.from(challenge.codeHash, 'hex');
      const given = hashCode(shopId, phone, code);
      if (!timingSafeEqual(expected, given)) {
        const attemptsLeft = OTP_MAX_ATTEMPTS - (challenge.attempts + 1);
        throw new AppError('OTP_INVALID', 400, 'Incorrect code', { attemptsLeft: Math.max(0, attemptsLeft) });
      }

      const consumed = await db.otpChallenge.updateMany({
        where: { id: challenge.id, consumedAt: null },
        data: { consumedAt: now() },
      });
      if (consumed.count === 0) throw new AppError('OTP_EXPIRED', 400, 'Code expired, request a new one');
    },
  };
}

export type OtpService = ReturnType<typeof createOtpService>;
