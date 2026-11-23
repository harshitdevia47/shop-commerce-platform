import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { AppError, requireShopId, type Logger } from '@qc/common';
import { SignJWT, importPKCS8 } from 'jose';
import type { Db } from '../../db.js';
import type { User } from '../../generated/prisma/client.js';

export interface TokenPair {
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt: string;
}

export interface TokenServiceOptions {
  db: Db;
  logger: Logger;
  privateKeyPem: string;
  issuer: string;
  accessTtlSeconds: number;
  refreshTtlDays: number;
  now?: () => Date;
}

const hashToken = (raw: string): string => createHash('sha256').update(raw).digest('hex');

export async function createTokenService(options: TokenServiceOptions) {
  const { db, logger, issuer, accessTtlSeconds, refreshTtlDays } = options;
  const now = options.now ?? (() => new Date());
  const signingKey = await importPKCS8(options.privateKeyPem, 'RS256');

  async function signAccessToken(user: Pick<User, 'id' | 'shopId' | 'role'>): Promise<{ token: string; expiresAt: Date }> {
    const issuedAt = Math.floor(now().getTime() / 1000);
    const expiresAt = new Date((issuedAt + accessTtlSeconds) * 1000);
    const token = await new SignJWT({ shopId: user.shopId, role: user.role, typ: 'access' })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setSubject(user.id)
      .setIssuer(issuer)
      .setIssuedAt(issuedAt)
      .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
      .setJti(randomUUID())
      .sign(signingKey);
    return { token, expiresAt };
  }

  async function revokeFamily(familyId: string, reason: string): Promise<void> {
    await db.refreshToken.updateMany({
      where: { familyId, revokedAt: null },
      data: { revokedAt: now(), revokedReason: reason },
    });
  }

  return {
    /** New session (login): new refresh-token family. */
    async issue(user: User, userAgent?: string, familyId: string = randomUUID()): Promise<TokenPair> {
      const access = await signAccessToken(user);
      const raw = randomBytes(32).toString('base64url');
      const refreshExpiresAt = new Date(now().getTime() + refreshTtlDays * 86_400_000);
      await db.refreshToken.create({
        data: {
          shopId: requireShopId(),
          userId: user.id,
          familyId,
          tokenHash: hashToken(raw),
          expiresAt: refreshExpiresAt,
          userAgent: userAgent?.slice(0, 200),
        },
      });
      return {
        accessToken: access.token,
        accessTokenExpiresAt: access.expiresAt.toISOString(),
        refreshToken: raw,
        refreshTokenExpiresAt: refreshExpiresAt.toISOString(),
      };
    },

    /**
     * Rotates a refresh token. Presenting an already-rotated token means it was
     * stolen or replayed: the whole family (session) is revoked.
     */
    async refresh(raw: string, userAgent?: string): Promise<{ tokens: TokenPair; user: User }> {
      const stored = await db.refreshToken.findUnique({ where: { tokenHash: hashToken(raw) }, include: { user: true } });
      if (!stored) throw new AppError('REFRESH_TOKEN_INVALID', 401, 'Session expired, please log in again');

      if (stored.revokedAt) {
        await revokeFamily(stored.familyId, 'reuse_detected');
        logger.warn({ userId: stored.userId, familyId: stored.familyId }, 'refresh token reuse detected');
        throw new AppError('REFRESH_TOKEN_REUSED', 401, 'Session expired, please log in again');
      }
      if (stored.expiresAt <= now()) {
        throw new AppError('REFRESH_TOKEN_EXPIRED', 401, 'Session expired, please log in again');
      }
      if (stored.user.isBlocked) {
        await revokeFamily(stored.familyId, 'blocked');
        throw new AppError('USER_BLOCKED', 403, 'This account is blocked');
      }

      // Conditional update: if a concurrent request already rotated this token, treat it as reuse.
      const rotated = await db.refreshToken.updateMany({
        where: { id: stored.id, revokedAt: null },
        data: { revokedAt: now(), revokedReason: 'rotated' },
      });
      if (rotated.count === 0) {
        await revokeFamily(stored.familyId, 'reuse_detected');
        throw new AppError('REFRESH_TOKEN_REUSED', 401, 'Session expired, please log in again');
      }

      const tokens = await this.issue(stored.user, userAgent, stored.familyId);
      return { tokens, user: stored.user };
    },

    /** Logout: revokes every token of the session. Unknown tokens are ignored. */
    /** Ends the session; returns its user (null for an unknown token). */
    async revoke(raw: string): Promise<string | null> {
      const stored = await db.refreshToken.findUnique({ where: { tokenHash: hashToken(raw) } });
      if (!stored) return null;
      await revokeFamily(stored.familyId, 'logout');
      return stored.userId;
    },

    /** Used when a user is blocked or their role changes. */
    async revokeAllForUser(userId: string, reason: string): Promise<void> {
      await db.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: now(), revokedReason: reason },
      });
    },
  };
}

export type TokenService = Awaited<ReturnType<typeof createTokenService>>;
