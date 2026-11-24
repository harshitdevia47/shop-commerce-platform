import { PrismaPg } from '@prisma/adapter-pg';
import { tenantScopeExtension } from '@qc/common';
import { Prisma, PrismaClient } from './generated/prisma/client.js';

/** Models that carry shop_id and must always be scoped to the current shop. */
export const TENANT_MODELS = [
  Prisma.ModelName.SaleOrder,
  Prisma.ModelName.SaleItem,
  Prisma.ModelName.SalePayment,
  Prisma.ModelName.ProcessedEvent,
] as const;

/**
 * `db` is the only client application code may use.
 * `rawPrisma` is unscoped: allowed only here, in main.ts, scripts/, and tests.
 */
export function createDb(databaseUrl: string) {
  const rawPrisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: databaseUrl }) });
  const db = rawPrisma.$extends(tenantScopeExtension(TENANT_MODELS));
  return { rawPrisma, db };
}

export type Database = ReturnType<typeof createDb>;
export type Db = Database['db'];
