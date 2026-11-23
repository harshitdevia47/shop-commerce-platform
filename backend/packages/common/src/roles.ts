export const ROLES = ['CUSTOMER', 'OWNER', 'STAFF', 'RIDER'] as const;

export type Role = (typeof ROLES)[number];

/** Roles that may use shop admin features. */
export const ADMIN_ROLES: readonly Role[] = ['OWNER', 'STAFF'];

export function isRole(value: unknown): value is Role {
  return typeof value === 'string' && (ROLES as readonly string[]).includes(value);
}
