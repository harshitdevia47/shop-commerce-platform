/**
 * Users CLI (needs the tenant service running to resolve shop slugs).
 *   npm run users -- create-owner <slug> <phone> [name]
 *   npm run users -- set-role <slug> <phone> <CUSTOMER|OWNER|STAFF|RIDER>
 *   npm run users -- list <slug>
 */
import { randomUUID } from 'node:crypto';
import { ROLES, createInternalClient, isRole, runWithContext, type Role } from '@qc/common';
import { createDb } from '../src/db.js';
import { normalizeIndianMobile } from '../src/modules/auth/phone.js';
import { createUsersService } from '../src/modules/users/users.service.js';

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set (create services/identity/.env from .env.example)`);
  return value;
}

async function resolveShopId(slug: string): Promise<string> {
  const tenant = createInternalClient({
    baseUrl: requireEnv('TENANT_URL'),
    secret: requireEnv('INTERNAL_HMAC_SECRET'),
    caller: 'identity-cli',
  });
  const shop = await tenant.get<{ id: string; isActive: boolean }>(`/internal/shops/by-slug/${encodeURIComponent(slug)}`);
  return shop.id;
}

function parsePhone(input: string | undefined): string {
  const phone = input ? normalizeIndianMobile(input) : null;
  if (!phone) throw new Error(`Invalid Indian mobile number: ${input ?? '(missing)'}`);
  return phone;
}

async function main(): Promise<number> {
  const [command, slug, ...rest] = process.argv.slice(2);
  if (!command || !slug) {
    console.error('Usage: users <create-owner <slug> <phone> [name] | set-role <slug> <phone> <role> | list <slug>>');
    return 1;
  }

  const shopId = await resolveShopId(slug);
  const { rawPrisma, db } = createDb(requireEnv('DATABASE_URL'));
  const users = createUsersService(db);

  try {
    return await runWithContext({ requestId: randomUUID(), shopId }, async () => {
      switch (command) {
        case 'create-owner': {
          const [phoneArg, ...nameParts] = rest;
          const user = await users.upsertWithRole(parsePhone(phoneArg), 'OWNER', nameParts.join(' ') || undefined);
          console.log(`✔ ${user.phone} is OWNER of ${slug} (user ${user.id})`);
          return 0;
        }
        case 'set-role': {
          const [phoneArg, roleArg] = rest;
          if (!isRole(roleArg)) throw new Error(`Role must be one of ${ROLES.join(', ')}`);
          const user = await users.upsertWithRole(parsePhone(phoneArg), roleArg as Role);
          console.log(`✔ ${user.phone} is ${user.role} of ${slug}`);
          console.log('  Note: an already logged-in user gets the new role on their next token refresh (max 15 min).');
          return 0;
        }
        case 'list': {
          const rows = await db.user.findMany({
            select: { phone: true, name: true, role: true, isBlocked: true, lastLoginAt: true },
            orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
          });
          console.table(rows);
          return 0;
        }
        default:
          console.error(`Unknown command ${command}`);
          return 1;
      }
    });
  } finally {
    await rawPrisma.$disconnect();
  }
}

main().then(
  (code) => process.exit(code),
  (err: unknown) => {
    console.error(err instanceof Error ? err.message : err);
    process.exit(1);
  },
);
