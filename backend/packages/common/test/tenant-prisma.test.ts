import { describe, expect, it, vi } from 'vitest';
import { TenantContextError, runWithContext, scopeArgs, tenantScopeExtension } from '../src/index.js';

const SHOP = 'shop-a';

describe('scopeArgs', () => {
  it.each(['findMany', 'findFirst', 'findUnique', 'count', 'update', 'updateMany', 'delete', 'deleteMany'])(
    'adds shopId to where for %s',
    (operation) => {
      expect(scopeArgs(operation, { where: { id: 'x' } }, SHOP).where).toEqual({ id: 'x', shopId: SHOP });
    },
  );

  it('adds where when none given', () => {
    expect(scopeArgs('findMany', undefined, SHOP)).toEqual({ where: { shopId: SHOP } });
  });

  it('sets shopId on create', () => {
    expect(scopeArgs('create', { data: { name: 'n' } }, SHOP).data).toEqual({ name: 'n', shopId: SHOP });
  });

  it('sets shopId on every createMany row', () => {
    const result = scopeArgs('createMany', { data: [{ a: 1 }, { a: 2 }] }, SHOP);
    expect(result.data).toEqual([
      { a: 1, shopId: SHOP },
      { a: 2, shopId: SHOP },
    ]);
  });

  it('scopes upsert where and create', () => {
    const result = scopeArgs('upsert', { where: { id: 'x' }, create: { a: 1 }, update: { a: 2 } }, SHOP);
    expect(result.where).toEqual({ id: 'x', shopId: SHOP });
    expect(result.create).toEqual({ a: 1, shopId: SHOP });
  });

  it('refuses to read another shop', () => {
    expect(() => scopeArgs('findMany', { where: { shopId: 'shop-b' } }, SHOP)).toThrow(TenantContextError);
  });

  it('refuses shopId filter objects (fail closed)', () => {
    expect(() => scopeArgs('findMany', { where: { shopId: { in: [SHOP, 'shop-b'] } } }, SHOP)).toThrow(
      TenantContextError,
    );
  });

  it('refuses to create rows for another shop', () => {
    expect(() => scopeArgs('create', { data: { shopId: 'shop-b' } }, SHOP)).toThrow(TenantContextError);
  });

  it('refuses to move rows to another shop', () => {
    expect(() => scopeArgs('update', { where: { id: 'x' }, data: { shopId: 'shop-b' } }, SHOP)).toThrow(
      TenantContextError,
    );
  });

  it('refuses unknown operations', () => {
    expect(() => scopeArgs('somethingNew', {}, SHOP)).toThrow(TenantContextError);
  });
});

describe('tenantScopeExtension', () => {
  const ext = tenantScopeExtension(['Product']);
  const run = ext.query.$allModels.$allOperations;

  it('passes non-tenant models through untouched', async () => {
    const query = vi.fn(async (a: unknown) => a);
    await run({ model: 'Shop', operation: 'findMany', args: { where: { id: 1 } }, query });
    expect(query).toHaveBeenCalledWith({ where: { id: 1 } });
  });

  it('throws outside tenant context', () => {
    const query = vi.fn(async (a: unknown) => a);
    expect(() => run({ model: 'Product', operation: 'findMany', args: {}, query })).toThrow(TenantContextError);
    expect(query).not.toHaveBeenCalled();
  });

  it('scopes tenant models using the context shopId', async () => {
    const query = vi.fn(async (a: unknown) => a);
    await runWithContext({ requestId: 'r', shopId: SHOP }, () =>
      run({ model: 'Product', operation: 'findMany', args: {}, query }),
    );
    expect(query).toHaveBeenCalledWith({ where: { shopId: SHOP } });
  });
});
