import { Errors, requireShopId } from '@qc/common';
import type { Db } from '../../db.js';
import { Prisma, type Role, type User } from '../../generated/prisma/client.js';

export interface PublicUser {
  id: string;
  phone: string;
  name: string | null;
  role: Role;
  locale: string | null;
}

export const toPublicUser = (user: User): PublicUser => ({
  id: user.id,
  phone: user.phone,
  name: user.name,
  role: user.role,
  locale: user.locale,
});

export function createUsersService(db: Db, now: () => Date = () => new Date()) {
  return {
    /** Finds or creates the customer account for a verified phone in the current shop. */
    async loginByPhone(phone: string): Promise<{ user: User; isNewUser: boolean }> {
      const shopId = requireShopId();
      const existing = await db.user.findUnique({ where: { shopId_phone: { shopId, phone } } });
      if (existing) {
        if (existing.isBlocked) throw Errors.forbidden('USER_BLOCKED', 'This account is blocked');
        const user = await db.user.update({ where: { id: existing.id }, data: { lastLoginAt: now() } });
        return { user, isNewUser: false };
      }
      try {
        const user = await db.user.create({ data: { shopId, phone, lastLoginAt: now() } });
        return { user, isNewUser: true };
      } catch (err) {
        // Two parallel first logins: the other request created the user.
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          return this.loginByPhone(phone);
        }
        throw err;
      }
    },

    async getById(id: string): Promise<User> {
      const user = await db.user.findUnique({ where: { id } });
      if (!user) throw Errors.notFound('USER_NOT_FOUND', 'User not found');
      return user;
    },

    async updateProfile(id: string, data: { name?: string; locale?: string }): Promise<User> {
      await this.getById(id);
      return db.user.update({ where: { id }, data });
    },

    /** Creates or promotes a user to a role (used by the users CLI for shop owners). */
    async upsertWithRole(phone: string, role: Role, name?: string): Promise<User> {
      const shopId = requireShopId();
      return db.user.upsert({
        where: { shopId_phone: { shopId, phone } },
        create: { shopId, phone, role, name },
        update: { role, ...(name ? { name } : {}) },
      });
    },
  };
}

export type UsersService = ReturnType<typeof createUsersService>;
