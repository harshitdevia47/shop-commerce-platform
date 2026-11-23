import type { PaymentsConfig } from '@qc/config-schema';
import type { Payment, PaymentMethod } from '../generated/prisma/client.js';

/** What the app shows the customer to pay. */
export interface PaymentInstructions {
  /** `upi://pay?...` intent opening any UPI app with amount and note filled in. */
  upiUri?: string;
}

/**
 * One way of paying. Adding Razorpay later = a new provider + enum value; order and app
 * code only see the method name and the instructions.
 */
export interface PaymentProvider {
  readonly method: PaymentMethod;
  isEnabled(config: PaymentsConfig): boolean;
  instructions(payment: Payment, config: PaymentsConfig): PaymentInstructions;
}

export const codProvider: PaymentProvider = {
  method: 'COD',
  isEnabled: (config) => config.cod,
  instructions: () => ({}),
};

/** Rupees with exactly two decimals, as the UPI spec expects: 12050 -> "120.50". */
export const upiAmount = (paise: number) => `${Math.floor(paise / 100)}.${String(paise % 100).padStart(2, '0')}`;

/**
 * UPI intent link (NPCI deep-link spec). Not auto-verifiable: the customer submits the UTR
 * and the owner confirms in their bank app.
 */
export const upiProvider: PaymentProvider = {
  method: 'UPI',
  isEnabled: (config) => config.upi.enabled && !!config.upi.vpa,
  instructions(payment, config) {
    const params = new URLSearchParams({
      pa: config.upi.vpa!,
      pn: config.upi.payeeName ?? '',
      am: upiAmount(payment.amountPaise),
      cu: 'INR',
      tn: `Order #${payment.orderNumber}`,
      tr: payment.id.replaceAll('-', ''),
    });
    // Spaces as %20 (not +) and a literal @ in the VPA: some UPI apps reject `pa=shop%40okaxis`.
    return { upiUri: `upi://pay?${params.toString().replaceAll('+', '%20').replace(/^pa=([^&]*)%40/, 'pa=$1@')}` };
  },
};

export const PROVIDERS: Record<PaymentMethod, PaymentProvider> = { COD: codProvider, UPI: upiProvider };
