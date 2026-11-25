import { AppError, type Logger } from '@qc/common';
import { Router, type Request, type RequestHandler, type Response } from 'express';
import { PAGE_HEADERS, html, page, type Html } from '../../web/layout.js';
import { doneText, homeView, pauseConfirmView, shopView } from '../../web/views.js';
import type { ShopDirectory, ShopNumbers, ShopSummary } from './shop-directory.js';
import { istToday } from './status.js';
import type { ActionResult, SubscriptionsService } from './subscriptions.service.js';

export interface PagesDeps {
  subscriptions: SubscriptionsService;
  directory: ShopDirectory;
  admin: RequestHandler;
  logger: Logger;
  payTo?: string;
  defaultFeeRupees?: number;
  now?: () => Date;
}

const NUMBERS_TTL_MS = 60_000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

class FormError extends Error {}

const text = (req: Request, name: string) => (typeof req.body?.[name] === 'string' ? (req.body[name] as string).trim() : '');

function paiseFrom(value: string, label: string): number {
  if (!/^\d{1,7}(\.\d{1,2})?$/.test(value)) throw new FormError(`${label}: enter an amount in rupees, like 999 or 999.50`);
  const paise = Math.round(Number(value) * 100);
  if (paise <= 0) throw new FormError(`${label}: must be more than ₹0`);
  return paise;
}

function intFrom(value: string, label: string, min: number, max: number): number {
  const n = Number(value);
  if (!/^\d+$/.test(value) || n < min || n > max) throw new FormError(`${label}: enter a number from ${min} to ${max}`);
  return n;
}

function dayFrom(value: string, label: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(Date.parse(`${value}T00:00:00Z`))) throw new FormError(`${label}: choose a date`);
  return value;
}

export function pagesRouter(deps: PagesDeps): Router {
  const { subscriptions, directory, admin, logger } = deps;
  const now = deps.now ?? (() => new Date());
  const router = Router();
  const cache = new Map<string, { at: number; numbers: ShopNumbers }>();

  const monthStart = () => `${istToday(now()).slice(0, 7)}-01`;
  async function numbers(shopId: string, fresh = false): Promise<ShopNumbers> {
    const hit = cache.get(shopId);
    if (!fresh && hit && now().getTime() - hit.at < NUMBERS_TTL_MS) return hit.numbers;
    const value = await directory.numbers(shopId, monthStart());
    cache.set(shopId, { at: now().getTime(), numbers: value });
    return value;
  }

  const send = (res: Response, title: string, body: Html, status = 200) =>
    res.status(status).set(PAGE_HEADERS).send(page(title, body, { admin: res.locals.admin as string }));

  async function shopOr404(req: Request, res: Response): Promise<ShopSummary | null> {
    const id = String(req.params.id);
    const shop = UUID.test(id) ? (await directory.list()).find((s) => s.id === id) : undefined;
    if (!shop) {
      res.status(404).set(PAGE_HEADERS).send(page('Not found', html`<h1>Shop not found</h1><p><a href="/">All shops</a></p>`));
      return null;
    }
    return shop;
  }

  async function renderShop(res: Response, shop: ShopSummary, extra: { notice?: string; error?: string } = {}, status = 200) {
    const [detail, n] = await Promise.all([subscriptions.get(shop.id), numbers(shop.id, true)]);
    send(res, shop.name, shopView({ shop, ...detail, numbers: n, today: istToday(now()), payTo: deps.payTo, defaultFeeRupees: deps.defaultFeeRupees, ...extra }), status);
  }

  router.get('/', admin, async (_req, res) => {
    const rows = await subscriptions.overview();
    const withNumbers = await Promise.all(rows.map(async (r) => ({ ...r, numbers: await numbers(r.shop.id) })));
    send(res, 'Shops', homeView(withNumbers));
  });

  router.get('/shops/:id', admin, async (req, res) => {
    const shop = await shopOr404(req, res);
    if (shop) await renderShop(res, shop, { notice: doneText(req.query.done) });
  });

  router.get('/shops/:id/pause', admin, async (req, res) => {
    const shop = await shopOr404(req, res);
    if (shop) send(res, 'Pause orders', pauseConfirmView(shop));
  });

  /** Runs a form action, then redirects back to the shop page (POST → redirect → GET). */
  const action = (name: string, run: (shop: ShopSummary, req: Request, res: Response) => Promise<ActionResult>) =>
    router.post(`/shops/:id/${name}`, admin, async (req, res) => {
      const shop = await shopOr404(req, res);
      if (!shop) return;
      try {
        const result = await run(shop, req, res);
        res.redirect(303, `/shops/${shop.id}?done=${result === 'repeat' ? 'repeat' : name}`);
      } catch (error) {
        if (error instanceof FormError || error instanceof AppError) {
          logger.info({ shopId: shop.id, action: name, reason: error.message }, 'admin form refused');
          await renderShop(res, shop, { error: error.message }, 400);
          return;
        }
        throw error;
      }
    });

  const formId = (req: Request) => text(req, 'formId') || undefined;

  action('setup', (shop, req) =>
    subscriptions.setup(shop.id, { feePaise: paiseFrom(text(req, 'fee'), 'Monthly fee'), dueDay: intFrom(text(req, 'dueDay'), 'Due day', 1, 28), formId: formId(req) }),
  );
  action('edit', (shop, req) =>
    subscriptions.edit(shop.id, { feePaise: paiseFrom(text(req, 'fee'), 'Monthly fee'), dueDay: intFrom(text(req, 'dueDay'), 'Due day', 1, 28), formId: formId(req) }),
  );
  action('paid', (shop, req, res) =>
    subscriptions.markPaid(shop.id, {
      amountPaise: paiseFrom(text(req, 'amount'), 'Amount'),
      months: intFrom(text(req, 'months'), 'Months covered', 1, 12),
      upiRef: text(req, 'upiRef').slice(0, 40) || undefined,
      paidOn: dayFrom(text(req, 'paidOn'), 'Paid on'),
      note: text(req, 'note').slice(0, 200) || undefined,
      by: res.locals.admin as string,
      formId: formId(req),
    }),
  );
  action('extend', (shop, req) => subscriptions.extend(shop.id, formId(req)));
  action('pause', (shop, req) => subscriptions.pause(shop.id, formId(req)));
  action('resume', (shop, req) => subscriptions.resume(shop.id, formId(req)));
  action('checklist', (shop, req) => subscriptions.setChecklist(shop.id, { logoDone: text(req, 'logoDone') === '1', playDone: text(req, 'playDone') === '1' }));

  return router;
}
