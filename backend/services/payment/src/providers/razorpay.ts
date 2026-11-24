import { createHmac, timingSafeEqual } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { z } from 'zod';

/**
 * Razorpay (online payments: UPI, cards, netbanking). Each shop has its own Razorpay account,
 * so money goes straight to the shop. Keys live in a server secrets folder, one file per shop
 * (`<dir>/<slug>.json`), never in git or client.json.
 *
 * Flow: the payment service creates a Razorpay order when the order is placed; the app opens
 * Razorpay Checkout with it; the app sends back the signed result (checked here), and Razorpay's
 * webhook confirms it again if the app never comes back.
 */

const credentialsSchema = z
  .object({
    keyId: z.string().regex(/^rzp_(test|live)_/, 'keyId must start with rzp_test_ or rzp_live_'),
    keySecret: z.string().min(8),
    webhookSecret: z.string().min(8),
  })
  .strict();

export type RazorpayCredentials = z.infer<typeof credentialsSchema>;

/** Shop slug → credentials (null when the shop has no Razorpay account set up). */
export interface RazorpayAccounts {
  get(slug: string): RazorpayCredentials | null;
}

export function fileRazorpayAccounts(dir: string | undefined): RazorpayAccounts {
  const cache = new Map<string, RazorpayCredentials | null>();
  return {
    get(slug) {
      if (!dir || !/^[a-z][a-z0-9_]*$/.test(slug)) return null;
      if (!cache.has(slug)) {
        try {
          cache.set(slug, credentialsSchema.parse(JSON.parse(readFileSync(join(dir, `${slug}.json`), 'utf8'))));
        } catch {
          cache.set(slug, null);
        }
      }
      return cache.get(slug)!;
    },
  };
}

export interface RazorpayApi {
  /** POST /v1/orders. Amount in paise. */
  createOrder(credentials: RazorpayCredentials, input: { amountPaise: number; receipt: string; notes: Record<string, string> }): Promise<{ id: string }>;
}

export function httpRazorpayApi(fetchImpl: typeof fetch = fetch, baseUrl = 'https://api.razorpay.com'): RazorpayApi {
  return {
    async createOrder(credentials, input) {
      const response = await fetchImpl(`${baseUrl}/v1/orders`, {
        method: 'POST',
        headers: {
          authorization: `Basic ${Buffer.from(`${credentials.keyId}:${credentials.keySecret}`).toString('base64')}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ amount: input.amountPaise, currency: 'INR', receipt: input.receipt.slice(0, 40), notes: input.notes }),
        signal: AbortSignal.timeout(8000),
      });
      const body = (await response.json().catch(() => ({}))) as { id?: string; error?: { description?: string } };
      if (!response.ok || !body.id) throw new Error(`Razorpay order failed (${response.status}): ${body.error?.description ?? 'unknown'}`);
      return { id: body.id };
    },
  };
}

function hmacMatches(secret: string, payload: string | Buffer, signature: string): boolean {
  const expected = Buffer.from(createHmac('sha256', secret).update(payload).digest('hex'));
  const given = Buffer.from(signature);
  return expected.length === given.length && timingSafeEqual(expected, given);
}

/** Checkout success handler: signature = HMAC_SHA256(key_secret, "<order_id>|<payment_id>"). */
export function paymentSignatureValid(credentials: RazorpayCredentials, orderId: string, paymentId: string, signature: string): boolean {
  return hmacMatches(credentials.keySecret, `${orderId}|${paymentId}`, signature);
}

/** Webhooks: X-Razorpay-Signature = HMAC_SHA256(webhook_secret, raw body). */
export function webhookSignatureValid(credentials: RazorpayCredentials, rawBody: Buffer, signature: string): boolean {
  return hmacMatches(credentials.webhookSecret, rawBody, signature);
}
