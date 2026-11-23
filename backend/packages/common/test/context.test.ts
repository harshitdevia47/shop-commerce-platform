import { describe, expect, it } from 'vitest';
import { getContext, requireShopId, runWithContext } from '../src/index.js';

/** Mimics PrismaPromise: does nothing until .then() is called. */
function lazy<T>(fn: () => T): PromiseLike<T> {
  return {
    then(onFulfilled, onRejected) {
      return new Promise<T>((resolve) => resolve(fn())).then(onFulfilled, onRejected);
    },
  };
}

describe('runWithContext', () => {
  it('returns sync results unchanged', () => {
    expect(runWithContext({ requestId: 'r', shopId: 's' }, () => requireShopId())).toBe('s');
  });

  it('keeps context for lazy thenables awaited outside the callback', async () => {
    const result = await runWithContext({ requestId: 'r', shopId: 'shop-a' }, () => lazy(() => requireShopId()));
    expect(result).toBe('shop-a');
  });

  it('does not leak context afterwards', async () => {
    await runWithContext({ requestId: 'r', shopId: 'shop-a' }, async () => undefined);
    expect(getContext()).toBeUndefined();
  });
});
