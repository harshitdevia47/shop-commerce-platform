import { createLogger } from '@qc/common';
import { describe, expect, it } from 'vitest';
import { consolePushSender, fcmPushSender } from '../src/index.js';

// The full FCM flow (OAuth + send + invalid tokens) is tested in services/notification.
describe('@qc/fcm', () => {
  it('console sender counts what it would send', async () => {
    const sender = consolePushSender(createLogger('t', 'silent'));
    expect(await sender.send([{ token: 't', title: 'a', body: 'b', data: {}, channelId: 'c' }])).toEqual({ sent: 1, invalidTokens: [] });
  });

  it('refuses an incomplete service account', () => {
    expect(() => fcmPushSender('{"project_id":"p"}', createLogger('t', 'silent'))).toThrow(/service account/);
  });
});
