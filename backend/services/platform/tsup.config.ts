import { defineConfig } from 'tsup';

export default defineConfig({
  // docker compose exec platform node dist/main.js runs the admin site.
  entry: { main: 'src/main.ts' },
  format: ['esm'],
  platform: 'node',
  target: 'node22',
  outDir: 'dist',
  clean: true,
  sourcemap: true,
  // Keep every npm package external (resolved from node_modules at runtime); bundle only
  // workspace packages, which ship as TypeScript source.
  skipNodeModulesBundle: true,
  noExternal: [/^@qc\//],
});
