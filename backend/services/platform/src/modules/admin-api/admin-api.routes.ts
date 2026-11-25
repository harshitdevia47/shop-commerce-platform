import { Errors, handler } from '@qc/common';
import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import type { AuthService } from '../auth/auth.service.js';
import type { ShopDirectory, ShopNumbers, ShopSummary } from '../subscriptions/shop-directory.js';
import { STATUS_ORDER, istToday, type Status } from '../subscriptions/status.js';
import type { SubscriptionsService } from '../subscriptions/subscriptions.service.js';
import { bearerToken, requireAdmin } from './bearer.js';

export interface AdminApiDeps {
  auth: AuthService;
  subscriptions: SubscriptionsService;
  directory: ShopDirectory;
  payTo?: string;
  defaultFeeRupees?: number;
  now?: () => Date;
}

const NUMBERS_TTL_MS = 60_000;

/** "999", "1,499.50", "₹999" → paise. */
const rupees = (label: string) =>
  z
    .union([z.string(), z.number()])
    .transform((v) => String(v).replace(/[₹,\s]/g, ''))
    .refine((v) => /^\d{1,6}(\.\d{1,2})?$/.test(v) && Number(v) > 0 && Number(v) <= 100_000, `${label}: enter an amount in rupees, like 999`)
    .transform((v) => Math.round(Number(v) * 100));
const dueDay = z.coerce.number().int().min(1, 'Due day: from 1 to 28').max(28, 'Due day: from 1 to 28');
const formId = z.string().trim().min(8).max(64).optional();
const isoDay = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Choose a date');

const feeBody = z.object({ feeRupees: rupees('Monthly fee'), dueDay, formId }).strict();
const paidBody = z
  .object({
    amountRupees: rupees('Amount'),
    months: z.coerce.number().int().min(1, 'Months covered: from 1 to 12').max(12, 'Months covered: from 1 to 12'),
    upiRef: z.string().trim().max(40).optional(),
    paidOn: isoDay,
    note: z.string().trim().max(200).optional(),
    formId,
  })
  .strict();
const idParams = z.object({ id: z.uuid() });

/** JSON API of the Shop Admin app. Every route except login needs a bearer session. */
export function adminApiRouter(deps: AdminApiDeps): Router {
  const { auth, subscriptions, directory } = deps;
  const now = deps.now ?? (() => new Date());
  const router = Router();
  const admin = requireAdmin(auth);
  const cache = new Map<string, { at: number; numbers: ShopNumbers }>();

  const monthStart = () => `${istToday(now()).slice(0, 7)}-01`;
  async function numbers(shopId: string, fresh = false): Promise<ShopNumbers> {
    const hit = cache.get(shopId);
    if (!fresh && hit && now().getTime() - hit.at < NUMBERS_TTL_MS) return hit.numbers;
    const value = await directory.numbers(shopId, monthStart());
    cache.set(shopId, { at: now().getTime(), numbers: value });
    return value;
  }

  async function shopById(id: string): Promise<ShopSummary> {
    const shop = (await directory.list()).find((s) => s.id === id);
    if (!shop) throw Errors.notFound('SHOP_NOT_FOUND', 'Shop not found');
    return shop;
  }

  async function shopDetail(shop: ShopSummary) {
    const [detail, n] = await Promise.all([subscriptions.get(shop.id), numbers(shop.id, true)]);
    return { shop, ...detail, numbers: n, today: istToday(now()), payTo: deps.payTo ?? null, defaultFeeRupees: deps.defaultFeeRupees ?? null };
  }

  router.post(
    '/api/admin/login/code',
    handler({ body: z.object({ email: z.string().trim().pipe(z.email('Enter your email address')) }).strict() }, async ({ body }, req) => {
      await auth.requestCode(body.email, req.ip ?? 'unknown');
      return { sent: true };
    }),
  );
  router.post(
    '/api/admin/login/verify',
    handler({ body: z.object({ email: z.string().min(3), code: z.string().trim() }).strict() }, async ({ body }) => ({
      token: await auth.verifyCode(body.email, body.code),
      email: body.email.trim().toLowerCase(),
    })),
  );
  router.post('/api/admin/logout', async (req: Request, res: Response) => {
    await auth.logout(bearerToken(req));
    res.status(204).end();
  });

  router.use('/api/admin', admin);

  router.put(
    '/api/admin/device',
    handler({ body: z.object({ token: z.string().min(20).max(4096), platform: z.enum(['android']) }).strict() }, async ({ body }, _req, res) => {
      await auth.registerDevice(res.locals.session as { id: string; email: string }, body.token, body.platform);
      res.status(204).end();
    }),
  );

  router.get(
    '/api/admin/overview',
    handler({}, async () => {
      const rows = await subscriptions.overview();
      const withNumbers = await Promise.all(rows.map(async (r) => ({ ...r, numbers: await numbers(r.shop.id) })));
      const counts = Object.fromEntries(STATUS_ORDER.map((s) => [s, rows.filter((r) => r.status === s).length])) as Record<Status, number>;
      return { rows: withNumbers, counts, today: istToday(now()) };
    }),
  );

  router.get('/api/admin/shops/:id', handler({ params: idParams }, async ({ params }) => shopDetail(await shopById(params.id))));

  const action = <S extends z.ZodType>(name: string, body: S, run: (shopId: string, input: z.output<S>, email: string) => Promise<'done' | 'repeat'>) =>
    router.post(
      `/api/admin/shops/:id/${name}`,
      handler({ params: idParams, body }, async ({ params, body: input }, _req, res) => {
        const shop = await shopById(params.id);
        const result = await run(shop.id, input as z.output<S>, (res.locals.session as { email: string }).email);
        return { result, shop: await shopDetail(shop) };
      }),
    );

  const onlyForm = z.object({ formId }).strict();
  action('setup', feeBody, (id, b) => subscriptions.setup(id, { feePaise: b.feeRupees, dueDay: b.dueDay, formId: b.formId }));
  action('edit', feeBody, (id, b) => subscriptions.edit(id, { feePaise: b.feeRupees, dueDay: b.dueDay, formId: b.formId }));
  action('paid', paidBody, (id, b, email) =>
    subscriptions.markPaid(id, {
      amountPaise: b.amountRupees,
      months: b.months,
      upiRef: b.upiRef || undefined,
      paidOn: b.paidOn,
      note: b.note || undefined,
      by: email,
      formId: b.formId,
    }),
  );
  action('extend', onlyForm, (id, b) => subscriptions.extend(id, b.formId));
  action('pause', onlyForm, (id, b) => subscriptions.pause(id, b.formId));
  action('resume', onlyForm, (id, b) => subscriptions.resume(id, b.formId));
  action('checklist', z.object({ logoDone: z.boolean(), playDone: z.boolean() }).strict(), (id, b) => subscriptions.setChecklist(id, b));

  return router;
}
