import { requireShop } from '@qc/common';
import { Router, type Response } from 'express';
import type { ShopsService } from '../shops/shops.service.js';
import { privacyPolicyHtml, termsHtml, type LegalOperator } from './legal.pages.js';

/**
 * Public pages (gateway: /legal/<slug>/privacy, /legal/<slug>/terms, shop from the path) for the
 * Play Store listing and the app's Account screen.
 */
export function legalRouter(shops: ShopsService, operator: LegalOperator): Router {
  const router = Router();

  const send = (res: Response, html: string) => {
    res
      .status(200)
      .set({
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'public, max-age=300',
        'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'",
      })
      .send(html);
  };

  const context = async () => {
    const config = await shops.getCurrentConfig();
    return {
      shop: config.shop,
      features: config.features,
      payments: config.payments,
      returnsWindow: config.returns.windowDays,
      operator,
      // Pages sit side by side under /legal/<slug>/.
      privacyUrl: 'privacy',
      termsUrl: 'terms',
    };
  };

  router.get('/legal/:slug/privacy', requireShop, async (_req, res) => send(res, privacyPolicyHtml(await context())));
  router.get('/legal/:slug/terms', requireShop, async (_req, res) => send(res, termsHtml(await context())));
  return router;
}
