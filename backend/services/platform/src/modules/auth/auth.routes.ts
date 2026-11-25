import { AppError } from '@qc/common';
import { Router, type Request, type Response } from 'express';
import { PAGE_HEADERS, html, page, type Html } from '../../web/layout.js';
import type { AuthService } from './auth.service.js';
import { clearSessionCookie, cookieName, readCookie, setSessionCookie, type CookieOptions } from './session.js';

const send = (res: Response, title: string, body: Html, status = 200) => res.status(status).set(PAGE_HEADERS).send(page(title, body));
const field = (req: Request, name: string) => (typeof req.body?.[name] === 'string' ? (req.body[name] as string) : '');

function emailForm(error?: string, email = '') {
  return html`<h1>Log in</h1>
<div class="card">
  ${error ? html`<p class="notice card error">${error}</p>` : ''}
  <form class="stack" method="post" action="/login">
    <label>Your email<input type="email" name="email" value="${email}" autocomplete="email" required autofocus></label>
    <button class="primary" type="submit">Send me a login code</button>
  </form>
</div>`;
}

function codeForm(email: string, error?: string) {
  return html`<h1>Enter the code</h1>
<div class="card">
  ${error ? html`<p class="notice card error">${error}</p>` : html`<p>If ${email} may use this site, a 6-digit code is on its way. Check your Gmail (and Spam).</p>`}
  <form class="stack" method="post" action="/login/verify">
    <input type="hidden" name="email" value="${email}">
    <label>6-digit code<input name="code" inputmode="numeric" pattern="[0-9]{6}" maxlength="6" autocomplete="one-time-code" required autofocus></label>
    <button class="primary" type="submit">Log in</button>
  </form>
  <p class="small"><a href="/login">Use another email or get a new code</a></p>
</div>`;
}

export function authRouter(auth: AuthService, cookie: CookieOptions): Router {
  const router = Router();

  router.get('/login', (_req, res) => send(res, 'Log in', emailForm()));

  router.post('/login', async (req, res) => {
    const email = field(req, 'email').trim();
    if (!email.includes('@')) return send(res, 'Log in', emailForm('Enter your email address.', email), 400);
    try {
      await auth.requestCode(email, req.ip ?? 'unknown');
    } catch (error) {
      if (error instanceof AppError) return send(res, 'Log in', emailForm(error.message, email), error.status);
      throw error;
    }
    return send(res, 'Enter the code', codeForm(email));
  });

  router.post('/login/verify', async (req, res) => {
    const email = field(req, 'email');
    try {
      const token = await auth.verifyCode(email, field(req, 'code').trim());
      setSessionCookie(res, token, cookie);
      return res.redirect(303, '/');
    } catch (error) {
      if (error instanceof AppError) return send(res, 'Enter the code', codeForm(email, error.message), error.status);
      throw error;
    }
  });

  router.post('/logout', async (req, res) => {
    await auth.logout(readCookie(req, cookieName(cookie)));
    clearSessionCookie(res, cookie);
    res.redirect(303, '/login');
  });

  return router;
}
