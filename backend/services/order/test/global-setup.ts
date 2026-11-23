import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

/**
 * Applies pending migrations to the test database once per run (non-destructive).
 * Tests clean up the rows they create themselves.
 */
export default function setup(): void {
  const cwd = fileURLToPath(new URL('..', import.meta.url));
  const url = process.env.TEST_DATABASE_URL ?? 'postgresql://qc:qc_dev_password@localhost:5433/qc_order_test';
  if (!/_test(\?|$)/.test(url)) throw new Error(`Refusing to run tests against non-test database: ${url}`);
  try {
    execFileSync('npx', ['prisma', 'migrate', 'deploy'], {
      cwd,
      env: { ...process.env, DATABASE_URL: url },
      stdio: 'pipe',
    });
  } catch (err) {
    const stderr = (err as { stderr?: Buffer }).stderr?.toString() ?? '';
    throw new Error(`Test database migration failed (is \`npm run infra:up\` running?)\n${stderr}`);
  }
}
