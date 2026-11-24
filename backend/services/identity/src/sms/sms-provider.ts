import type { Logger } from '@qc/common';

export interface OtpMessage {
  /** E.164 */
  phone: string;
  code: string;
}

/**
 * Pluggable SMS sender. Indian providers need a DLT-registered sender ID and OTP
 * template; each is a class here plus a value in SMS_PROVIDERS (env.ts).
 */
export interface SmsProvider {
  readonly name: string;
  sendOtp(message: OtpMessage): Promise<void>;
}

/** Development: writes the OTP to the service log instead of sending an SMS. */
export class ConsoleSmsProvider implements SmsProvider {
  readonly name = 'console';

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

export type SmsProviderConfig = { name: 'console' } | ({ name: 'msg91' } & Msg91Options);

export function createSmsProvider(config: SmsProviderConfig, logger: Logger): SmsProvider {
  switch (config.name) {
    case 'console':
      return new ConsoleSmsProvider(logger);
    case 'msg91':
      return new Msg91SmsProvider(config, logger);
  }
}
