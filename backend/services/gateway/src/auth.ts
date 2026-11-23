import { AppError } from '@qc/common';

export { createAccessTokenVerifier, type AccessClaims, type AccessTokenVerifier } from '@qc/common';

export function bearerToken(header: string | undefined): string | undefined {
  if (!header) return undefined;
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  if (!match) throw new AppError('TOKEN_INVALID', 401, 'Authorization header must be "Bearer <token>"');
  return match[1];
}
