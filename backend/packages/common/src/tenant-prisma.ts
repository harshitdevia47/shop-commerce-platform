import { requireShopId, TenantContextError } from './context.js';

/**
 * Tenant scoping for Prisma.
 *
 * `tenantScopeExtension(models)` returns a Prisma query extension that injects the
 * current request's shopId into every operation on the listed models:
 *   - reads / updates / deletes: `where.shopId = shopId`
 *     (works for findUnique/update/delete too: Prisma accepts extra non-unique
 *     filters in unique where inputs)
 *   - creates: `data.shopId = shopId`
 * It fails closed: unknown operations, missing context, or an attempt to target
 * a different shopId all throw.
 */

type Args = Record<string, unknown> | undefined;

const WHERE_OPERATIONS = new Set([
  'findUnique',
  'findUniqueOrThrow',
  'findFirst',
  'findFirstOrThrow',
  'findMany',
  'count',
  'aggregate',
  'groupBy',
  'update',
  'updateMany',
  'updateManyAndReturn',
  'delete',
  'deleteMany',
]);

const CREATE_OPERATIONS = new Set(['create', 'createMany', 'createManyAndReturn']);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function scopedWhere(where: unknown, shopId: string): Record<string, unknown> {
  const base = isRecord(where) ? where : {};
  if (base.shopId !== undefined && base.shopId !== shopId) {
    throw new TenantContextError('Query targets a different shop than the current context');
  }
  return { ...base, shopId };
}

function scopedData(data: unknown, shopId: string): Record<string, unknown> {
  const base = isRecord(data) ? data : {};
  if (base.shopId !== undefined && base.shopId !== shopId) {
    throw new TenantContextError('Write targets a different shop than the current context');
  }
  return { ...base, shopId };
}

function assertNoShopChange(data: unknown, shopId: string): void {
  if (isRecord(data) && data.shopId !== undefined && data.shopId !== shopId) {
    throw new TenantContextError('Rows cannot be moved to another shop');
  }
}

export function scopeArgs(operation: string, args: Args, shopId: string): Record<string, unknown> {
  const scoped: Record<string, unknown> = { ...(args ?? {}) };

  if (WHERE_OPERATIONS.has(operation)) {
    scoped.where = scopedWhere(scoped.where, shopId);
    assertNoShopChange(scoped.data, shopId);
    return scoped;
  }

  if (CREATE_OPERATIONS.has(operation)) {
    scoped.data = Array.isArray(scoped.data)
      ? scoped.data.map((row) => scopedData(row, shopId))
      : scopedData(scoped.data, shopId);
    return scoped;
  }

  if (operation === 'upsert') {
    scoped.where = scopedWhere(scoped.where, shopId);
    scoped.create = scopedData(scoped.create, shopId);
    assertNoShopChange(scoped.update, shopId);
    return scoped;
  }

  throw new TenantContextError(`Operation "${operation}" is not supported on tenant-scoped models`);
}

interface QueryParams {
  model?: string;
  operation: string;
  args: unknown;
  query: (args: unknown) => Promise<unknown>;
}

export function tenantScopeExtension(tenantModels: readonly string[]) {
  const models = new Set(tenantModels);
  return {
    name: 'tenant-scope',
    query: {
      $allModels: {
        $allOperations({ model, operation, args, query }: QueryParams): Promise<unknown> {
          if (!model || !models.has(model)) return query(args);
          return query(scopeArgs(operation, args as Args, requireShopId()));
        },
      },
    },
  };
}
