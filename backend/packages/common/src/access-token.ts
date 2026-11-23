import { AppError } from './errors.js';
import { ROLES, type Role } from './roles.js';
import { errors as joseErrors, importSPKI, jwtVerify } from 'jose';
import { z } from 'zod';

export interface AccessClaims {
  userId: string;
  shopId: string;
  role: Role;
  /** Expiry, epoch seconds. */
  expiresAt: number;
}

export type AccessTokenVerifier = (token: string) => Promise<AccessClaims>;

const claimsSchema = z.object({
  sub: z.string().min(1),
  shopId: z.string().min(1),
  role: z.enum(ROLES),
  typ: z.literal('access'),
  exp: z.number(),
});

/** Verifies RS256 access tokens issued by the identity service (gateway HTTP, realtime sockets). */
export async function createAccessTokenVerifier(publicKeyPem: string, issuer: string): Promise<AccessTokenVerifier> {
  const key = await importSPKI(publicKeyPem, 'RS256');
  return async (token) => {
    let payload: unknown;
    try {
      ({ payload } = await jwtVerify(token, key, { issuer, algorithms: ['RS256'] }));
    } catch (err) {
      if (err instanceof joseErrors.JWTExpired) throw new AppError('TOKEN_EXPIRED', 401, 'Access token expired');
      throw new AppError('TOKEN_INVALID', 401, 'Invalid access token');
    }
    const claims = claimsSchema.safeParse(payload);
    if (!claims.success) throw new AppError('TOKEN_INVALID', 401, 'Invalid access token');
    return { userId: claims.data.sub, shopId: claims.data.shopId, role: claims.data.role, expiresAt: claims.data.exp };
  };
}
