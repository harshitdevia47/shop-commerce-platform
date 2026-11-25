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

/** Asks the order service how many orders of a customer are still in progress. */
export interface OpenOrders {
  countFor(userId: string): Promise<number>;
}

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
      if (!user || user.deletedAt) throw Errors.notFound('USER_NOT_FOUND', 'User not found');
      return user;
    },

    async updateProfile(id: string, data: { name?: string; locale?: string }): Promise<User> {
      await this.getById(id);
      return db.user.update({ where: { id }, data });
    },

    /**
     * The person deletes their own account (Google Play requires this in the app). Only customers:
     * the owner's account is the shop's (platform support handles it) and staff/riders are removed
     * by the owner. Refused while an order is still in progress, so it can still be delivered.
     *
     * The user row stays (orders elsewhere point to its id) but loses phone, name and language;
     * addresses, devices and sessions are deleted. The same phone logging in later gets a new account.
     */
    async deleteAccount(id: string, orders: OpenOrders): Promise<void> {
      const user = await this.getById(id);
      if (user.role === 'OWNER') {
        throw Errors.conflict('ACCOUNT_DELETE_OWNER', 'The shop owner account is closed through platform support');
      }
      if (user.role !== 'CUSTOMER') {
        throw Errors.conflict('ACCOUNT_DELETE_TEAM', 'Ask the shop owner to remove you from the team');
      }
      if ((await orders.countFor(id)) > 0) {
        throw Errors.conflict('ACCOUNT_HAS_OPEN_ORDERS', 'Wait until your orders are delivered or cancelled');
      }
      await db.$transaction([
        db.refreshToken.deleteMany({ where: { userId: id } }),
        db.device.deleteMany({ where: { userId: id } }),
        db.address.deleteMany({ where: { userId: id } }),
        db.user.update({
          where: { id },
          data: { phone: `deleted:${id}`, name: null, locale: null, isBlocked: true, deletedAt: now() },
        }),
      ]);
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
