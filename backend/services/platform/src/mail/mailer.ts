import type { Logger } from '@qc/common';
import nodemailer from 'nodemailer';

export interface MailMessage {
  to: string;
  subject: string;
  text: string;
  html?: string;
}

export interface Mailer {
  send(message: MailMessage): Promise<void>;
}

export type MailConfig = { provider: 'console' } | { provider: 'gmail'; user: string; appPassword: string };

/** Gmail SMTP with an app password (free), or the log in development. */
export function createMailer(config: MailConfig, logger: Logger): Mailer {
  if (config.provider === 'console') {
    return {
      async send(message) {
        logger.info({ to: message.to, subject: message.subject }, `mail (console)\n${message.text}`);
      },
    };
  }
  const transport = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true,
    auth: { user: config.user, pass: config.appPassword },
  });
  return {
    async send(message) {
      await transport.sendMail({ from: `Shop apps admin <${config.user}>`, ...message });
    },
  };
}
