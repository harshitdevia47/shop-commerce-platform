/**
 * Client config CLI.
 *   npm run client -- validate [slug]   validate one client (or all) incl. asset files
 *   npm run client -- sync <slug>       validate, then create/update the shop in the tenant DB
 *   npm run client -- list              list shops in the tenant DB
 */
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { safeParseClientConfig, type ClientConfig } from '@qc/config-schema';
import { z } from 'zod';
import { createDb } from '../src/db.js';
import { createShopsService } from '../src/modules/shops/shops.service.js';

const clientsDir = process.env.CLIENTS_DIR ?? fileURLToPath(new URL('../../../../clients/', import.meta.url));

function allSlugs(): string[] {
  return readdirSync(clientsDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith('_') && !entry.name.startsWith('.'))
    .map((entry) => entry.name)
    .sort();
}

function validate(slug: string): { config?: ClientConfig; errors: string[] } {
  const dir = join(clientsDir, slug);
  const file = join(dir, 'client.json');
  if (!existsSync(file)) return { errors: [`${file} not found`] };

  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(file, 'utf8'));
  } catch (err) {
    return { errors: [`client.json is not valid JSON: ${(err as Error).message}`] };
  }

  const result = safeParseClientConfig(raw);
  if (!result.success) return { errors: [z.prettifyError(result.error)] };

  const config = result.data;
  const errors: string[] = [];
  if (config.slug !== slug) errors.push(`slug "${config.slug}" must match folder name "${slug}"`);
  for (const asset of [config.branding.logo, config.branding.icon]) {
    if (!existsSync(join(dir, asset))) errors.push(`missing asset ${asset}`);
  }
  return { config, errors };
}

function requireDb() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is not set (create services/tenant/.env from .env.example)');
  return createDb(url);
}

async function main(): Promise<number> {
  const [command, slugArg] = process.argv.slice(2);

  switch (command) {
    case 'validate': {
      const slugs = slugArg ? [slugArg] : allSlugs();
      let failed = 0;
      for (const slug of slugs) {
        const { errors } = validate(slug);
        if (errors.length === 0) {
          console.log(`✔ ${slug}`);
        } else {
          failed++;
          console.error(`✘ ${slug}\n  ${errors.join('\n  ')}`);
        }
      }
      return failed === 0 ? 0 : 1;
    }

    case 'sync': {
      if (!slugArg) throw new Error('Usage: client sync <slug>');
      const { config, errors } = validate(slugArg);
      if (!config || errors.length > 0) {
        console.error(`✘ ${slugArg}\n  ${errors.join('\n  ')}`);
        return 1;
      }
      const { rawPrisma, db } = requireDb();
      try {
        // Shop is the tenant root (not a tenant-scoped model), so this works without request context.
        const shop = await createShopsService(db).upsertFromClientConfig(config);
        console.log(`✔ synced ${shop.slug} (id ${shop.id}, active ${shop.isActive})`);
      } finally {
        await rawPrisma.$disconnect();
      }
      return 0;
    }

    case 'list': {
      const { rawPrisma } = requireDb();
      try {
        const shops = await rawPrisma.shop.findMany({
          select: { id: true, slug: true, name: true, businessType: true, isActive: true },
          orderBy: { slug: 'asc' },
        });
        console.table(shops);
      } finally {
        await rawPrisma.$disconnect();
      }
      return 0;
    }

    default:
      console.error('Usage: client <validate [slug] | sync <slug> | list>');
      return 1;
  }
}

main().then(
  (code) => process.exit(code),
  (err: unknown) => {
    console.error(err instanceof Error ? err.message : err);
    process.exit(1);
  },
);
