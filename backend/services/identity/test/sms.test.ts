import { createLogger } from '@qc/common';
import { describe, expect, it } from 'vitest';
import { loadIdentityEnv } from '../src/env.js';
import { Msg91SmsProvider, WhatsAppOtpProvider } from '../src/sms/sms-provider.js';

const logger = createLogger('sms-test', 'silent');

function fakeFetch(status: number, body: unknown) {
  const calls: { url: string; init: RequestInit }[] = [];
  const impl = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(typeof body === 'string' ? body : JSON.stringify(body), { status });
  }) as typeof fetch;
  return { calls, impl };
}

describe('MSG91', () => {
  const options = { authKey: 'auth-key', templateId: 'tpl-123', otpVariable: 'otp' };

  it('sends the code to the number without +, with the template and auth key', async () => {
    const http = fakeFetch(200, { type: 'success', message: '3463...' });
    await new Msg91SmsProvider(options, logger, http.impl).sendOtp({ phone: '+919876543210', code: '482913' });
    expect(http.calls).toHaveLength(1);
    expect(http.calls[0]!.url).toBe('https://control.msg91.com/api/v5/flow');
    expect((http.calls[0]!.init.headers as Record<string, string>).authkey).toBe('auth-key');
    expect(JSON.parse(String(http.calls[0]!.init.body))).toEqual({
      template_id: 'tpl-123',
      short_url: '0',
      recipients: [{ mobiles: '919876543210', otp: '482913' }],
    });
  });

  it('fails (so the user sees "could not send") on errors, including 200 with type=error', async () => {
    const provider = (status: number, body: unknown) => new Msg91SmsProvider(options, logger, fakeFetch(status, body).impl);
    await expect(provider(200, { type: 'error', message: 'Template not approved' }).sendOtp({ phone: '+919876543210', code: '1' })).rejects.toThrow();
    await expect(provider(401, 'Unauthorized').sendOtp({ phone: '+919876543210', code: '1' })).rejects.toThrow('401');
  });
});

describe('WhatsApp OTP', () => {
  const options = { phoneNumberId: '1234567890', accessToken: 'token-abc', templateName: 'login_code' };

  it('sends the authentication template in the app language, with the code in body and copy button', async () => {
    const http = fakeFetch(200, { messages: [{ id: 'wamid.x' }] });
    const provider = new WhatsAppOtpProvider(options, logger, http.impl);
    await provider.sendOtp({ phone: '+919876543210', code: '482913', locale: 'gu' });
    await provider.sendOtp({ phone: '+919876543210', code: '111111', locale: 'xx' });
    expect(http.calls[0]!.url).toBe('https://graph.facebook.com/v21.0/1234567890/messages');
    expect((http.calls[0]!.init.headers as Record<string, string>).authorization).toBe('Bearer token-abc');
    expect(JSON.parse(String(http.calls[0]!.init.body))).toEqual({
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: '919876543210',
      type: 'template',
      template: {
        name: 'login_code',
        language: { code: 'gu' },
        components: [
          { type: 'body', parameters: [{ type: 'text', text: '482913' }] },
          { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: '482913' }] },
        ],
      },
    });
    expect(JSON.parse(String(http.calls[1]!.init.body)).template.language.code).toBe('en'); // unknown language: English
  });

  it('fails on API errors so the user can retry', async () => {
    const http = fakeFetch(400, { error: { code: 132001, message: 'Template name does not exist' } });
    await expect(new WhatsAppOtpProvider(options, logger, http.impl).sendOtp({ phone: '+919876543210', code: '1' })).rejects.toThrow('400');
  });
});

describe('SMS settings', () => {
  const base = {
    DATABASE_URL: 'postgresql://x/y',
    REDIS_URL: 'redis://x',
    ORDER_URL: 'http://order:3000',
    INTERNAL_HMAC_SECRET: 'x'.repeat(40),
    OTP_SECRET: 'y'.repeat(40),
    JWT_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----',
  };

  it('msg91 needs its key and template; production refuses console SMS', () => {
    expect(() => loadIdentityEnv({ ...base, SMS_PROVIDER: 'msg91' })).toThrow(/MSG91_AUTH_KEY/);
    expect(() => loadIdentityEnv({ ...base, SMS_PROVIDER: 'whatsapp' })).toThrow(/WHATSAPP_ACCESS_TOKEN/);
    expect(
      loadIdentityEnv({ ...base, NODE_ENV: 'production', SMS_PROVIDER: 'whatsapp', WHATSAPP_PHONE_NUMBER_ID: '123', WHATSAPP_ACCESS_TOKEN: 't' }).WHATSAPP_OTP_TEMPLATE,
    ).toBe('login_code');
    expect(loadIdentityEnv({ ...base, SMS_PROVIDER: 'msg91', MSG91_AUTH_KEY: 'k', MSG91_OTP_TEMPLATE_ID: 't' }).MSG91_OTP_VARIABLE).toBe('otp');
    expect(() => loadIdentityEnv({ ...base, NODE_ENV: 'production' })).toThrow(/console SMS provider/);
    expect(loadIdentityEnv({ ...base, NODE_ENV: 'production', SMS_PROVIDER: 'msg91', MSG91_AUTH_KEY: 'k', MSG91_OTP_TEMPLATE_ID: 't' }).SMS_PROVIDER).toBe('msg91');
  });
});
