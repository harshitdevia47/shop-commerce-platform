import { AppError, ROLES, type Role } from '@qc/common';
import { errors as joseErrors, importSPKI, jwtVerify } from 'jose';
import { z } from 'zod';

export interface AccessClaims {
  userId: string;
  shopId: string;
  role: Role;
}

export type AccessTokenVerifier = (token: string) => Promise<AccessClaims>;

const claimsSchema = z.object({
  sub: z.string().min(1),
  shopId: z.string().min(1),
  role: z.enum(ROLES),
  typ: z.literal('access'),
});

/** Verifies RS256 access tokens issued by the identity service. */
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
    return { userId: claims.data.sub, shopId: claims.data.shopId, role: claims.data.role };
  };
}

export function bearerToken(header: string | undefined): string | undefined {
  if (!header) return undefined;
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  if (!match) throw new AppError('TOKEN_INVALID', 401, 'Authorization header must be "Bearer <token>"');
  return match[1];
}
