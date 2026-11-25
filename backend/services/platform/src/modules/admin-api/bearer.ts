import { AppError } from '@qc/common';
import type { NextFunction, Request, Response } from 'express';
import type { AuthService } from '../auth/auth.service.js';

export const bearerToken = (req: Request) => /^Bearer (.+)$/.exec(req.headers.authorization ?? '')?.[1];

/** Admin app requests carry `Authorization: Bearer <session token>` (no cookies, so no CSRF). */
export function requireAdmin(auth: AuthService) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const session = await auth.session(bearerToken(req));
      if (!session) return next(new AppError('ADMIN_AUTH_REQUIRED', 401, 'Please log in again'));
      res.locals.session = session;
      next();
    } catch (error) {
      next(error);
    }
  };
}
