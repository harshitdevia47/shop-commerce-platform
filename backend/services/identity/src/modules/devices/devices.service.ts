import { ADMIN_ROLES, requireShopId } from '@qc/common';
import type { Db } from '../../db.js';

export const MAX_DEVICES_PER_USER = 10;

export interface DeviceInput {
  token: string;
  platform: 'android' | 'ios';
  locale: string;
}

export interface PushTarget {
  userId: string;
  token: string;
  platform: string;
  locale: string;
}

export function createDevicesService(db: Db) {
  return {
    /**
     * Registers (or refreshes) this phone's push token for the user. A token already linked to
     * another account of the shop moves to this user: only the person logged in gets pushes.
     */
    async register(userId: string, input: DeviceInput): Promise<void> {
      await db.device.upsert({
        where: { shopId_token: { shopId: requireShopId(), token: input.token } },
        create: { shopId: requireShopId(), userId, ...input },
        update: { userId, platform: input.platform, locale: input.locale },
      });
      // Keep the newest few: old phones' tokens expire silently.
      const stale = await db.device.findMany({
        where: { userId },
        orderBy: { updatedAt: 'desc' },
        skip: MAX_DEVICES_PER_USER,
        select: { id: true },
      });
      if (stale.length > 0) await db.device.deleteMany({ where: { id: { in: stale.map((d) => d.id) } } });
    },

    /** Logout on this phone, or the push service reporting dead tokens. */
    async remove(tokens: string[], userId?: string): Promise<number> {
      const { count } = await db.device.deleteMany({ where: { token: { in: tokens }, ...(userId ? { userId } : {}) } });
      return count;
    },

    /** Tokens for these customers and/or the shop's admins (owner + staff). Blocked users get nothing. */
    async targets(query: { userIds?: string[]; admins?: boolean }): Promise<PushTarget[]> {
      const or = [
        ...(query.userIds?.length ? [{ userId: { in: query.userIds } }] : []),
        ...(query.admins ? [{ user: { role: { in: [...ADMIN_ROLES] } } }] : []),
      ];
      if (or.length === 0) return [];
      const rows = await db.device.findMany({
        where: { OR: or, user: { isBlocked: false } },
        select: { userId: true, token: true, platform: true, locale: true },
        orderBy: { updatedAt: 'desc' },
        take: 500,
      });
      return rows;
    },
  };
}

export type DevicesService = ReturnType<typeof createDevicesService>;
