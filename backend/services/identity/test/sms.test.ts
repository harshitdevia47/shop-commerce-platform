import { createLogger } from '@qc/common';
import { describe, expect, it } from 'vitest';
import { loadIdentityEnv } from '../src/env.js';
import { Msg91SmsProvider } from '../src/sms/sms-provider.js';

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

describe('SMS settings', () => {
  const base = {
    DATABASE_URL: 'postgresql://x/y',
    REDIS_URL: 'redis://x',
    INTERNAL_HMAC_SECRET: 'x'.repeat(40),
    OTP_SECRET: 'y'.repeat(40),
    JWT_PRIVATE_KEY: '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----',
  };

  it('msg91 needs its key and template; production refuses console SMS', () => {
    expect(() => loadIdentityEnv({ ...base, SMS_PROVIDER: 'msg91' })).toThrow(/MSG91_AUTH_KEY/);
    expect(loadIdentityEnv({ ...base, SMS_PROVIDER: 'msg91', MSG91_AUTH_KEY: 'k', MSG91_OTP_TEMPLATE_ID: 't' }).MSG91_OTP_VARIABLE).toBe('otp');
    expect(() => loadIdentityEnv({ ...base, NODE_ENV: 'production' })).toThrow(/console SMS provider/);
    expect(loadIdentityEnv({ ...base, NODE_ENV: 'production', SMS_PROVIDER: 'msg91', MSG91_AUTH_KEY: 'k', MSG91_OTP_TEMPLATE_ID: 't' }).SMS_PROVIDER).toBe('msg91');
  });
});
