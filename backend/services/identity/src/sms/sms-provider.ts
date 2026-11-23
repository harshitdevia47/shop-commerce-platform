import type { Logger } from '@qc/common';

export interface OtpMessage {
  /** E.164 */
  phone: string;
  code: string;
}

/**
 * Pluggable SMS sender. Real Indian providers (MSG91, Fast2SMS, ...) need a
 * DLT-registered sender ID and OTP template; add each as a class here and a
 * value in SMS_PROVIDERS (env.ts).
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

export function createSmsProvider(name: 'console', logger: Logger): SmsProvider {
  switch (name) {
    case 'console':
      return new ConsoleSmsProvider(logger);
  }
}
