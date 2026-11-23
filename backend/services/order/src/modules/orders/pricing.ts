import type { DeliveryConfig } from '@qc/config-schema';
import type { Fulfillment } from '../../generated/prisma/client.js';
import type { VariantSnapshot } from '../../upstreams.js';

export interface CartLine {
  variantId: string;
  qty: number;
}

export type LineIssue = 'UNAVAILABLE' | 'INSUFFICIENT_STOCK';

export interface QuoteLine extends Omit<VariantSnapshot, 'stockQty' | 'inStock'> {
  qty: number;
  lineTotalPaise: number;
  /** Set when the line cannot be ordered as is. */
  issue: LineIssue | null;
  /** For INSUFFICIENT_STOCK: how many can be ordered. */
  maxQty: number | null;
}

export interface Quote {
  lines: QuoteLine[];
  /** Variant ids the shop does not sell (deleted or unknown). */
  missing: string[];
  itemCount: number;
  subtotalPaise: number;
  deliveryFeePaise: number;
  totalPaise: number;
  /** MRP minus price across lines. */
  savingsPaise: number;
  minOrderPaise: number;
  /** Amount still needed to reach free delivery, if the shop offers it. */
  freeDeliveryGapPaise: number | null;
  canPlace: boolean;
}

/** Merges duplicate variants so a cart cannot sneak past stock checks with two lines. */
export function mergeLines(lines: CartLine[]): CartLine[] {
  const merged = new Map<string, number>();
  for (const line of lines) merged.set(line.variantId, (merged.get(line.variantId) ?? 0) + line.qty);
  return [...merged].map(([variantId, qty]) => ({ variantId, qty }));
}

/**
 * Prices a cart from the catalog's current data. Never trusts prices from the client.
 * Delivery fee: charged unless the subtotal reaches `freeAbovePaise`; pickup is free.
 */
export function priceCart(
  cart: CartLine[],
  snapshots: VariantSnapshot[],
  delivery: DeliveryConfig,
  fulfillment: Fulfillment,
): Quote {
  const byId = new Map(snapshots.map((s) => [s.variantId, s]));
  const lines: QuoteLine[] = [];
  const missing: string[] = [];

  for (const { variantId, qty } of mergeLines(cart)) {
    const snapshot = byId.get(variantId);
    if (!snapshot) {
      missing.push(variantId);
      continue;
    }
    const { stockQty, inStock, ...rest } = snapshot;
    let issue: LineIssue | null = null;
    let maxQty: number | null = null;
    if (!inStock) issue = 'UNAVAILABLE';
    else if (stockQty !== null && stockQty < qty) {
      issue = 'INSUFFICIENT_STOCK';
      maxQty = stockQty;
    }
    lines.push({ ...rest, qty, lineTotalPaise: snapshot.pricePaise * qty, issue, maxQty });
  }

  const orderable = lines.filter((l) => !l.issue);
  const subtotalPaise = orderable.reduce((sum, l) => sum + l.lineTotalPaise, 0);
  const savingsPaise = orderable.reduce((sum, l) => sum + Math.max(0, ((l.mrpPaise ?? l.pricePaise) - l.pricePaise) * l.qty), 0);
  const isDelivery = fulfillment === 'DELIVERY';
  const free = delivery.freeAbovePaise !== null && subtotalPaise >= delivery.freeAbovePaise;
  const deliveryFeePaise = isDelivery && subtotalPaise > 0 && !free ? delivery.feePaise : 0;
  const minOrderPaise = isDelivery ? delivery.minOrderPaise : 0;

  return {
    lines,
    missing,
    itemCount: orderable.reduce((sum, l) => sum + l.qty, 0),
    subtotalPaise,
    deliveryFeePaise,
    totalPaise: subtotalPaise + deliveryFeePaise,
    savingsPaise,
    minOrderPaise,
    freeDeliveryGapPaise:
      isDelivery && delivery.freeAbovePaise !== null && !free ? delivery.freeAbovePaise - subtotalPaise : null,
    canPlace: missing.length === 0 && lines.length > 0 && lines.every((l) => !l.issue) && subtotalPaise >= minOrderPaise,
  };
}

/** Great-circle distance in km (no paid distance APIs). */
export function haversineKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const rad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}
