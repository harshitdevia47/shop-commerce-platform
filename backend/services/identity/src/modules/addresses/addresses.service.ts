import { Errors, requireShopId } from '@qc/common';
import type { Db } from '../../db.js';
import type { Address } from '../../generated/prisma/client.js';

export const MAX_ADDRESSES = 10;

export interface AddressInput {
  label?: 'home' | 'work' | 'other';
  name?: string | null;
  phone?: string | null;
  line1: string;
  line2?: string | null;
  landmark?: string | null;
  city: string;
  pincode: string;
  lat?: number | null;
  lng?: number | null;
  isDefault?: boolean;
}

export type PublicAddress = Omit<Address, 'shopId' | 'userId' | 'deletedAt' | 'createdAt' | 'updatedAt'>;

export const toPublicAddress = ({ shopId: _s, userId: _u, deletedAt: _d, createdAt: _c, updatedAt: _up, ...rest }: Address): PublicAddress =>
  rest;

export function createAddressesService(db: Db, now: () => Date = () => new Date()) {
  async function get(userId: string, id: string): Promise<Address> {
    const address = await db.address.findFirst({ where: { id, userId, deletedAt: null } });
    if (!address) throw Errors.notFound('ADDRESS_NOT_FOUND', 'Address not found');
    return address;
  }

  return {
    get,

    /** Default first, then newest. */
    async list(userId: string): Promise<PublicAddress[]> {
      const rows = await db.address.findMany({
        where: { userId, deletedAt: null },
        orderBy: [{ isDefault: 'desc' }, { id: 'desc' }],
      });
      return rows.map(toPublicAddress);
    },

    async create(userId: string, input: AddressInput): Promise<PublicAddress> {
      const count = await db.address.count({ where: { userId, deletedAt: null } });
      if (count >= MAX_ADDRESSES) throw Errors.badRequest('ADDRESS_LIMIT', `At most ${MAX_ADDRESSES} addresses`);
      const isDefault = input.isDefault ?? count === 0; // the first address is the default
      const address = await db.$transaction(async (tx) => {
        if (isDefault) await tx.address.updateMany({ where: { userId, isDefault: true }, data: { isDefault: false } });
        return tx.address.create({ data: { ...input, isDefault, shopId: requireShopId(), userId } });
      });
      return toPublicAddress(address);
    },

    async update(userId: string, id: string, input: Partial<AddressInput>): Promise<PublicAddress> {
      await get(userId, id);
      const address = await db.$transaction(async (tx) => {
        if (input.isDefault) await tx.address.updateMany({ where: { userId, isDefault: true }, data: { isDefault: false } });
        return tx.address.update({ where: { id }, data: input });
      });
      return toPublicAddress(address);
    },

    async remove(userId: string, id: string): Promise<void> {
      const address = await get(userId, id);
      await db.$transaction(async (tx) => {
        await tx.address.update({ where: { id }, data: { deletedAt: now(), isDefault: false } });
        if (address.isDefault) {
          const next = await tx.address.findFirst({ where: { userId, deletedAt: null }, orderBy: { id: 'desc' } });
          if (next) await tx.address.update({ where: { id: next.id }, data: { isDefault: true } });
        }
      });
    },
  };
}

export type AddressesService = ReturnType<typeof createAddressesService>;
