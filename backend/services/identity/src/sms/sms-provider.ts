import type { Logger } from '@qc/common';

export interface OtpMessage {
  /** E.164 */
  phone: string;
  code: string;
  /** App language of the person logging in (en | gu | hi), when known. */
  locale?: string;
}

/**
 * Pluggable SMS sender. Indian providers need a DLT-registered sender ID and OTP
 * template; each is a class here plus a value in SMS_PROVIDERS (env.ts).
 */
export interface SmsProvider {
  readonly name: string;
  /** Where the customer should look for the code (the app says so on the code screen). */
  readonly channel: 'sms' | 'whatsapp';
  sendOtp(message: OtpMessage): Promise<void>;
}

/** Development: writes the OTP to the service log instead of sending an SMS. */
export class ConsoleSmsProvider implements SmsProvider {
  readonly name = 'console';
  readonly channel = 'sms' as const;

  constructor(private readonly logger: Logger) {}

  async sendOtp({ phone, code }: OtpMessage): Promise<void> {
    this.logger.warn({ phone, otp: code }, `DEV OTP for ${phone}: ${code}`);
  }
}

export interface Msg91Options {
  authKey: string;
  /** DLT-approved OTP template, created in the MSG91 panel (Flow). */
  templateId: string;
  /** Name of the template variable holding the code (`##otp##` in the template → `otp`). */
  otpVariable: string;
  baseUrl?: string;
  timeoutMs?: number;
}

/**
 * MSG91 Flow API (India, DLT). The template text and sender ID are registered on DLT and
 * configured in the MSG91 panel; this only sends the number and the code.
 * Docs: https://docs.msg91.com (Send SMS → Flow).
 */
export class Msg91SmsProvider implements SmsProvider {
  readonly name = 'msg91';
  readonly channel = 'sms' as const;

  constructor(
    private readonly options: Msg91Options,
    private readonly logger: Logger,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async sendOtp({ phone, code }: OtpMessage): Promise<void> {
    const response = await this.fetchImpl(`${this.options.baseUrl ?? 'https://control.msg91.com'}/api/v5/flow`, {
      method: 'POST',
      headers: { authkey: this.options.authKey, 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({
        template_id: this.options.templateId,
        short_url: '0',
        // MSG91 wants the country code without '+'.
        recipients: [{ mobiles: phone.replace(/^\+/, ''), [this.options.otpVariable]: code }],
      }),
      signal: AbortSignal.timeout(this.options.timeoutMs ?? 5000),
    });
    const text = await response.text();
    let body: { type?: string; message?: string } = {};
    try {
      body = JSON.parse(text) as typeof body;
    } catch {
      // Non-JSON error page.
    }
    if (!response.ok || body.type === 'error') {
      // Never log the code; the number is enough to trace.
      this.logger.error({ status: response.status, phone, providerMessage: body.message ?? text.slice(0, 200) }, 'MSG91 send failed');
      throw new Error(`MSG91 send failed (${response.status})`);
    }
  }
}

export interface WhatsAppOptions {
  /** WhatsApp Cloud API phone number id (Meta app → WhatsApp → API setup). */
  phoneNumberId: string;
  /** Permanent token of a system user with whatsapp_business_messaging permission. */
  accessToken: string;
  /** Approved template of category AUTHENTICATION with a "copy code" button. */
  templateName: string;
  /** App language → template language code (each language approved for the same template name). */
  languages?: Record<string, string>;
  apiVersion?: string;
  baseUrl?: string;
  timeoutMs?: number;
}

const DEFAULT_WHATSAPP_LANGUAGES: Record<string, string> = { en: 'en', gu: 'gu', hi: 'hi' };

/**
 * OTP over WhatsApp (Meta WhatsApp Business Cloud API, authentication template). No DLT needed;
 * Meta business verification and an approved template are. The code goes in the body parameter
 * and in the copy-code button, as authentication templates require.
 *
 * Note: WhatsApp accepts the request even when the number has no WhatsApp; delivery failures arrive
 * later on the webhook. Customers without WhatsApp need the SMS fallback.
 */
export class WhatsAppOtpProvider implements SmsProvider {
  readonly name = 'whatsapp';
  readonly channel = 'whatsapp' as const;

  constructor(
    private readonly options: WhatsAppOptions,
    private readonly logger: Logger,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async sendOtp({ phone, code, locale }: OtpMessage): Promise<void> {
    const languages = this.options.languages ?? DEFAULT_WHATSAPP_LANGUAGES;
    const language = (locale && languages[locale]) || languages.en || 'en';
    const url = `${this.options.baseUrl ?? 'https://graph.facebook.com'}/${this.options.apiVersion ?? 'v21.0'}/${this.options.phoneNumberId}/messages`;
    const response = await this.fetchImpl(url, {
      method: 'POST',
      headers: { authorization: `Bearer ${this.options.accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: phone.replace(/^\+/, ''),
        type: 'template',
        template: {
          name: this.options.templateName,
          language: { code: language },
          components: [
            { type: 'body', parameters: [{ type: 'text', text: code }] },
            { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: code }] },
          ],
        },
      }),
      signal: AbortSignal.timeout(this.options.timeoutMs ?? 5000),
    });
    if (!response.ok) {
      const body = (await response.json().catch(() => ({}))) as { error?: { code?: number; message?: string } };
      // Never log the code.
      this.logger.error({ status: response.status, phone, errorCode: body.error?.code, providerMessage: body.error?.message }, 'WhatsApp OTP send failed');
      throw new Error(`WhatsApp send failed (${response.status})`);
    }
  }
}

export type SmsProviderConfig =
  | { name: 'console' }
  | ({ name: 'msg91' } & Msg91Options)
  | ({ name: 'whatsapp' } & WhatsAppOptions);

export function createSmsProvider(config: SmsProviderConfig, logger: Logger): SmsProvider {
  switch (config.name) {
    case 'console':
      return new ConsoleSmsProvider(logger);
    case 'msg91':
      return new Msg91SmsProvider(config, logger);
    case 'whatsapp':
      return new WhatsAppOtpProvider(config, logger);
  }
}
