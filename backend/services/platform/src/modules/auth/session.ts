import type { NextFunction, Request, Response } from 'express';
import { SESSION_TTL_MS, type AuthService } from './auth.service.js';

export interface CookieOptions {
  /** Secure cookies (`__Host-` prefix) everywhere except local http development. */
  secure: boolean;
}

export const cookieName = ({ secure }: CookieOptions) => (secure ? '__Host-qc_admin' : 'qc_admin');

export function readCookie(req: Request, name: string): string | undefined {
  for (const part of (req.headers.cookie ?? '').split(';')) {
    const [key, ...rest] = part.trim().split('=');
    if (key === name) return decodeURIComponent(rest.join('='));
  }
  return undefined;
}

export function setSessionCookie(res: Response, token: string, options: CookieOptions): void {
  const attrs = [`${cookieName(options)}=${token}`, 'Path=/', 'HttpOnly', 'SameSite=Strict', `Max-Age=${SESSION_TTL_MS / 1000}`];
  if (options.secure) attrs.push('Secure');
  res.append('set-cookie', attrs.join('; '));
}

export function clearSessionCookie(res: Response, options: CookieOptions): void {
  res.append('set-cookie', `${cookieName(options)}=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0${options.secure ? '; Secure' : ''}`);
}

/**
 * Form posts must come from the admin site itself (SameSite=Strict already keeps the cookie off
 * cross-site requests; this also refuses posts without an Origin).
 */
export function requireSameOrigin(origin: string) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (req.method !== 'POST' || req.path.startsWith('/api/')) return next();
    const sent = req.headers.origin;
    // Some browsers send "Origin: null" (privacy settings); then trust their own Sec-Fetch-Site.
    const sameSite = sent === origin || ((sent === undefined || sent === 'null') && req.headers['sec-fetch-site'] === 'same-origin');
    if (!sameSite) {
      res.status(403).type('text/plain').send('Forbidden');
      return;
    }
    next();
  };
}

/** Pages need a signed-in admin: GETs go to the login page, other requests get 401. */
export function requireAdmin(auth: AuthService, options: CookieOptions) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const email = await auth.session(readCookie(req, cookieName(options)));
      if (!email) {
        if (req.method === 'GET') res.redirect(303, '/login');
        else res.status(401).type('text/plain').send('Please log in again');
        return;
      }
      res.locals.admin = email;
      next();
    } catch (error) {
      next(error);
    }
  };
}
