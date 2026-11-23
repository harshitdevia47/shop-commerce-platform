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
}

export interface UpstreamUrls {
  tenant: string;
}

/**
 * Public route table. Add a line per service as phases land.
 * `/internal/*` is never routed: it is not in this table and is explicitly blocked.
 */
export function buildRoutes(upstreams: UpstreamUrls): RouteRule[] {
  const rules: RouteRule[] = [
    { prefix: '/api/v1/shop', target: upstreams.tenant, auth: 'public' },
    { prefix: '/api/v1/admin/settings', target: upstreams.tenant, auth: 'required', roles: ADMIN_ROLES },
  ];
  // Longest prefix first so specific rules win.
  return rules.sort((a, b) => b.prefix.length - a.prefix.length);
}

export function matchRoute(rules: readonly RouteRule[], path: string): RouteRule | undefined {
  return rules.find((rule) => path === rule.prefix || path.startsWith(`${rule.prefix}/`));
}
