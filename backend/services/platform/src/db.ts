import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from './generated/prisma/client.js';

/**
 * The platform's own data is about shops, not inside a shop: no tenant scoping here.
 * Shop data of other services is only reached through their internal APIs.
 */
export function createDb(databaseUrl: string) {
  return new PrismaClient({ adapter: new PrismaPg({ connectionString: databaseUrl }) });
}

export type Db = ReturnType<typeof createDb>;
