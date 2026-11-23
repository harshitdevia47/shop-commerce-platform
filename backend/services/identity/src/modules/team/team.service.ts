import { Errors, requireShopId } from '@qc/common';
import type { Db } from '../../db.js';
import type { TokenService } from '../auth/token.service.js';

export const TEAM_ROLES = ['STAFF', 'RIDER'] as const;
export type TeamRole = (typeof TEAM_ROLES)[number];

export interface TeamMember {
  id: string;
  phone: string;
  name: string | null;
  role: 'OWNER' | TeamRole;
  isBlocked: boolean;
  lastLoginAt: Date | null;
}

const select = { id: true, phone: true, name: true, role: true, isBlocked: true, lastLoginAt: true } as const;

/**
 * The shop's people besides customers. Only the owner manages them (route guard).
 * Role changes revoke the user's sessions, so they take effect at the next login
 * (an access token already issued stays valid for at most 15 minutes).
 */
export function createTeamService(db: Db, tokens: TokenService) {
  return {
    async list(): Promise<TeamMember[]> {
      const rows = await db.user.findMany({
        where: { role: { in: ['OWNER', ...TEAM_ROLES] } },
        select,
        orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
      });
      return rows as TeamMember[];
    },

    /** Adds someone by phone (they log in with OTP as usual), or changes a member's role. */
    async add(phone: string, role: TeamRole, name?: string): Promise<TeamMember> {
      const shopId = requireShopId();
      const existing = await db.user.findUnique({ where: { shopId_phone: { shopId, phone } } });
      if (existing?.role === 'OWNER') throw Errors.conflict('OWNER_ROLE_LOCKED', "The owner's role cannot be changed here");
      const user = await db.user.upsert({
        where: { shopId_phone: { shopId, phone } },
        create: { shopId, phone, role, name: name ?? null },
        update: { role, ...(name ? { name } : {}) },
        select,
      });
      if (existing && existing.role !== role) await tokens.revokeAllForUser(existing.id, 'role_changed');
      return user as TeamMember;
    },

    /** Back to a plain customer account (orders and addresses stay). */
    async remove(userId: string): Promise<void> {
      const user = await db.user.findUnique({ where: { id: userId } });
      if (!user || !(TEAM_ROLES as readonly string[]).includes(user.role)) {
        throw Errors.notFound('TEAM_MEMBER_NOT_FOUND', 'Team member not found');
      }
      await db.user.update({ where: { id: userId }, data: { role: 'CUSTOMER' } });
      await tokens.revokeAllForUser(userId, 'role_changed');
    },

    /** Riders who can take deliveries (internal: delivery service). */
    async riders(): Promise<{ id: string; name: string | null; phone: string }[]> {
      return db.user.findMany({
        where: { role: 'RIDER', isBlocked: false },
        select: { id: true, name: true, phone: true },
        orderBy: { createdAt: 'asc' },
      });
    },
  };
}

export type TeamService = ReturnType<typeof createTeamService>;
