import { PRESETS } from '@qc/config-schema';
import { describe, expect, it } from 'vitest';
import { haversineKm, mergeLines, priceCart } from '../src/modules/orders/pricing.js';
import { TRANSITIONS, canTransition, nextStatuses } from '../src/modules/orders/status.js';
import type { VariantSnapshot } from '../src/upstreams.js';

const delivery = { ...PRESETS.grocery.delivery, feePaise: 2000, freeAbovePaise: 50000, minOrderPaise: 10000 };
const snap = (variantId: string, pricePaise: number, extra: Partial<VariantSnapshot> = {}): VariantSnapshot => ({
  variantId,
  productId: `p-${variantId}`,
  productName: variantId,
  productNameI18n: null,
  label: '1 kg',
  labelI18n: null,
  pricePaise,
  mrpPaise: null,
  thumbUrl: null,
  inStock: true,
  stockQty: null,
  ...extra,
});

describe('status machine', () => {
  it('customers may only cancel, and only before packing', () => {
    expect(nextStatuses('PLACED', 'DELIVERY', 'CUSTOMER')).toEqual(['CANCELLED']);
    expect(nextStatuses('CONFIRMED', 'DELIVERY', 'CUSTOMER')).toEqual(['CANCELLED']);
    expect(nextStatuses('PACKED', 'DELIVERY', 'CUSTOMER')).toEqual([]);
  });

  it('shop follows the fulfillment path', () => {
    expect(nextStatuses('PACKED', 'DELIVERY', 'OWNER')).toEqual(['OUT_FOR_DELIVERY', 'REJECTED']);
    expect(nextStatuses('PACKED', 'PICKUP', 'STAFF')).toEqual(['READY_FOR_PICKUP', 'REJECTED']);
    expect(canTransition('PLACED', 'DELIVERED', 'DELIVERY', 'OWNER')).toBe(false);
    expect(canTransition('OUT_FOR_DELIVERY', 'DELIVERED', 'DELIVERY', 'OWNER')).toBe(true);
  });

  it('riders and strangers get nothing (rider flow is Phase 5)', () => {
    expect(nextStatuses('OUT_FOR_DELIVERY', 'DELIVERY', 'RIDER')).toEqual([]);
    expect(nextStatuses('PLACED', 'DELIVERY', undefined)).toEqual([]);
  });

  it('terminal states have no exits', () => {
    for (const status of ['DELIVERED', 'PICKED_UP', 'CANCELLED', 'REJECTED'] as const) expect(TRANSITIONS[status]).toEqual([]);
  });
});

describe('pricing', () => {
  it('merges duplicate lines', () => {
    expect(mergeLines([{ variantId: 'a', qty: 1 }, { variantId: 'b', qty: 1 }, { variantId: 'a', qty: 2 }])).toEqual([
      { variantId: 'a', qty: 3 },
      { variantId: 'b', qty: 1 },
    ]);
  });

  it('charges delivery below the free threshold and sums savings', () => {
    const quote = priceCart([{ variantId: 'a', qty: 2 }], [snap('a', 12000, { mrpPaise: 14000 })], delivery, 'DELIVERY');
    expect(quote).toMatchObject({
      subtotalPaise: 24000,
      deliveryFeePaise: 2000,
      totalPaise: 26000,
      savingsPaise: 4000,
      freeDeliveryGapPaise: 26000,
      itemCount: 2,
      canPlace: true,
    });
  });

  it('free delivery at the threshold; pickup never pays delivery or minimum', () => {
    expect(priceCart([{ variantId: 'a', qty: 5 }], [snap('a', 10000)], delivery, 'DELIVERY')).toMatchObject({
      deliveryFeePaise: 0,
      freeDeliveryGapPaise: null,
    });
    expect(priceCart([{ variantId: 'a', qty: 1 }], [snap('a', 500)], delivery, 'PICKUP')).toMatchObject({
      deliveryFeePaise: 0,
      minOrderPaise: 0,
      canPlace: true,
    });
  });

  it('below minimum cannot be placed', () => {
    expect(priceCart([{ variantId: 'a', qty: 1 }], [snap('a', 5000)], delivery, 'DELIVERY').canPlace).toBe(false);
  });

  it('flags unavailable, short and missing lines and leaves them out of totals', () => {
    const quote = priceCart(
      [
        { variantId: 'ok', qty: 1 },
        { variantId: 'gone', qty: 1 },
        { variantId: 'short', qty: 5 },
        { variantId: 'unknown', qty: 1 },
      ],
      [snap('ok', 20000), snap('gone', 100, { inStock: false }), snap('short', 100, { stockQty: 2 })],
      delivery,
      'DELIVERY',
    );
    expect(quote.lines.map((l) => [l.variantId, l.issue, l.maxQty])).toEqual([
      ['ok', null, null],
      ['gone', 'UNAVAILABLE', null],
      ['short', 'INSUFFICIENT_STOCK', 2],
    ]);
    expect(quote.missing).toEqual(['unknown']);
    expect(quote.subtotalPaise).toBe(20000);
    expect(quote.canPlace).toBe(false);
  });

  it('haversine distance', () => {
    // Two points in Bhavnagar about 3.7 km apart.
    const km = haversineKm({ lat: 21.7645, lng: 72.1519 }, { lat: 21.7522, lng: 72.1852 });
    expect(km).toBeGreaterThan(3);
    expect(km).toBeLessThan(5);
  });
});
