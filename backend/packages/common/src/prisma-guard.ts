import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

/**
 * Files under `srcDir` (excluding generated code) that reference the unscoped `rawPrisma`
 * client outside the allowed entry points. Each service's tests assert this is empty.
 */
export function findRawPrismaOffenders(srcDir: string, allowed: readonly string[] = ['db.ts', 'main.ts']): string[] {
  const offenders: string[] = [];
  const walk = (dir: string) => {
    for (const name of readdirSync(dir)) {
      const path = join(dir, name);
      if (name === 'generated') continue;
      if (statSync(path).isDirectory()) walk(path);
      else if (name.endsWith('.ts') && /\brawPrisma\b/.test(readFileSync(path, 'utf8'))) {
        offenders.push(relative(srcDir, path));
      }
    }
  };
  walk(srcDir);
  return offenders.filter((file) => !allowed.includes(file));
}
