import type { Logger } from '@qc/common';
import { SignJWT, importPKCS8 } from 'jose';

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  /** String values only (FCM data payload). `route` is the app page a tap opens. */
  data: Record<string, string>;
  /** Android notification channel created by the app. */
  channelId: string;
  /** A newer notification with the same tag replaces the older one (one per order). */
  tag?: string;
}

export interface PushResult {
  sent: number;
  /** Tokens FCM says are gone (app uninstalled, data cleared): remove them. */
  invalidTokens: string[];
}

export interface PushSender {
  readonly name: string;
  send(messages: PushMessage[]): Promise<PushResult>;
}

/** Development and pilots without Firebase: logs what would be sent. */
export function consolePushSender(logger: Logger): PushSender {
  return {
    name: 'console',
    async send(messages) {
      for (const m of messages) {
        logger.info({ token: `${m.token.slice(0, 12)}…`, title: m.title, body: m.body, data: m.data }, 'push (console)');
      }
      return { sent: messages.length, invalidTokens: [] };
    },
  };
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

/**
 * FCM HTTP v1 with a service account (OAuth2 JWT bearer flow). Used instead of firebase-admin
 * to keep images small; FCM is the only Firebase service the platform uses.
 * One Firebase project serves every shop app (each app is registered in it).
 */
export function fcmPushSender(
  serviceAccountJson: string,
  logger: Logger,
  fetchImpl: typeof fetch = fetch,
  now: () => number = Date.now,
): PushSender {
  const account = JSON.parse(serviceAccountJson) as ServiceAccount;
  if (!account.project_id || !account.client_email || !account.private_key) {
    throw new Error('FCM service account JSON must have project_id, client_email and private_key');
  }
  const tokenUri = account.token_uri ?? 'https://oauth2.googleapis.com/token';
  const endpoint = `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;
  let cached: { token: string; expiresAt: number } | null = null;

  async function accessToken(): Promise<string> {
    if (cached && cached.expiresAt - 60_000 > now()) return cached.token;
    const key = await importPKCS8(account.private_key, 'RS256');
    const iat = Math.floor(now() / 1000);
    const assertion = await new SignJWT({ scope: SCOPE })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuer(account.client_email)
      .setAudience(tokenUri)
      .setIssuedAt(iat)
      .setExpirationTime(iat + 3600)
      .sign(key);
    const res = await fetchImpl(tokenUri, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    });
    if (!res.ok) throw new Error(`FCM auth failed: ${res.status} ${await res.text()}`);
    const json = (await res.json()) as { access_token: string; expires_in: number };
    cached = { token: json.access_token, expiresAt: now() + json.expires_in * 1000 };
    return cached.token;
  }

  async function sendOne(message: PushMessage, bearer: string): Promise<'sent' | 'invalid' | 'failed' | 'unavailable'> {
    const res = await fetchImpl(endpoint, {
      method: 'POST',
      headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: message.token,
          notification: { title: message.title, body: message.body },
          data: message.data,
          android: {
            priority: 'HIGH',
            notification: { channel_id: message.channelId, ...(message.tag ? { tag: message.tag } : {}) },
          },
        },
      }),
    });
    if (res.ok) return 'sent';
    const text = await res.text();
    // UNREGISTERED (404) = token gone; INVALID_ARGUMENT about the token = never valid.
    if (res.status === 404 || text.includes('UNREGISTERED') || (res.status === 400 && /registration token/i.test(text))) {
      return 'invalid';
    }
    logger.warn({ status: res.status, body: text.slice(0, 500) }, 'FCM send failed');
    return res.status === 429 || res.status >= 500 ? 'unavailable' : 'failed';
  }

  return {
    name: 'fcm',
    async send(messages) {
      if (messages.length === 0) return { sent: 0, invalidTokens: [] };
      const bearer = await accessToken();
      const results = await Promise.all(messages.map((m) => sendOne(m, bearer)));
      // Retry the event only when nothing got through (a retry re-sends to every phone).
      if (results.every((r) => r === 'unavailable')) throw new Error('FCM unavailable');
      return {
        sent: results.filter((r) => r === 'sent').length,
        invalidTokens: messages.filter((_, i) => results[i] === 'invalid').map((m) => m.token),
      };
    },
  };
}
