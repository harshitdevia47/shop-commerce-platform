import { ADMIN_ROLES, type Role } from '@qc/common';

/**
 * public:   no token needed (token, if sent, is still verified)
 * required: valid access token for this shop
 */
export type AuthMode = 'public' | 'required';

export interface RouteRule {
  /** Path prefix, matched on segment boundaries. */
  prefix: string;
  /** Upstream base URL. */
  target: string;
  auth: AuthMode;
  /** Coarse role gate; services still enforce their own rules. */
  roles?: readonly Role[];
  /** Callers that cannot send X-Shop-Key (payment webhooks): the shop slug is the next path segment. */
  shopKeyFromPath?: boolean;
}

export interface UpstreamUrls {
  tenant: string;
  identity: string;
  catalog: string;
  media: string;
  order: string;
  payment: string;
  delivery: string;
  reporting: string;
}

/**
 * Public route table. Add a line per service as phases land.
 * `/internal/*` is never routed: it is not in this table and is explicitly blocked.
 */
export function buildRoutes(upstreams: UpstreamUrls): RouteRule[] {
  const rules: RouteRule[] = [
    { prefix: '/api/v1/shop', target: upstreams.tenant, auth: 'public' },
    // Clients must NOT send an access token to /auth (it may be expired while refreshing).
    { prefix: '/api/v1/auth', target: upstreams.identity, auth: 'public' },
    { prefix: '/api/v1/me', target: upstreams.identity, auth: 'required' },
    { prefix: '/api/v1/admin/settings', target: upstreams.tenant, auth: 'required', roles: ADMIN_ROLES },
    { prefix: '/api/v1/catalog', target: upstreams.catalog, auth: 'public' },
    { prefix: '/api/v1/admin/catalog', target: upstreams.catalog, auth: 'required', roles: ADMIN_ROLES },
    { prefix: '/api/v1/admin/media', target: upstreams.media, auth: 'required', roles: ADMIN_ROLES },
    // Cart pricing is public so guests see totals; everything else about orders needs login.
    { prefix: '/api/v1/orders/quote', target: upstreams.order, auth: 'public' },
    { prefix: '/api/v1/orders/slots', target: upstreams.order, auth: 'public' },
    { prefix: '/api/v1/admin/returns', target: upstreams.order, auth: 'required', roles: ADMIN_ROLES },
    // Private photos (prescriptions, lists, return photos): upload and view, checked by media.
    { prefix: '/api/v1/media', target: upstreams.media, auth: 'required' },
    { prefix: '/api/v1/orders', target: upstreams.order, auth: 'required' },
    { prefix: '/api/v1/admin/orders', target: upstreams.order, auth: 'required', roles: ADMIN_ROLES },
    { prefix: '/api/v1/payments', target: upstreams.payment, auth: 'required' },
    { prefix: '/api/v1/admin/payments', target: upstreams.payment, auth: 'required', roles: ADMIN_ROLES },
    // Owner manages staff and riders.
    { prefix: '/api/v1/admin/team', target: upstreams.identity, auth: 'required', roles: ['OWNER'] },
    { prefix: '/api/v1/admin/riders', target: upstreams.delivery, auth: 'required', roles: ADMIN_ROLES },
    { prefix: '/api/v1/admin/deliveries', target: upstreams.delivery, auth: 'required', roles: ADMIN_ROLES },
    { prefix: '/api/v1/rider', target: upstreams.delivery, auth: 'required', roles: ['RIDER'] },
    { prefix: '/api/v1/deliveries', target: upstreams.delivery, auth: 'required' },
    // Razorpay webhooks: /api/v1/webhooks/razorpay/<slug>; the payment service checks the signature.
    { prefix: '/api/v1/webhooks/razorpay', target: upstreams.payment, auth: 'public', shopKeyFromPath: true },
    // Privacy policy and terms pages: /legal/<slug>/privacy|terms (opened in a browser, no X-Shop-Key).
    { prefix: '/legal', target: upstreams.tenant, auth: 'public', shopKeyFromPath: true },
    // Sales figures: owner only.
    { prefix: '/api/v1/admin/reports', target: upstreams.reporting, auth: 'required', roles: ['OWNER'] },
  ];
  // Longest prefix first so specific rules win.
  return rules.sort((a, b) => b.prefix.length - a.prefix.length);
}

export function matchRoute(rules: readonly RouteRule[], path: string): RouteRule | undefined {
  return rules.find((rule) => path === rule.prefix || path.startsWith(`${rule.prefix}/`));
}
