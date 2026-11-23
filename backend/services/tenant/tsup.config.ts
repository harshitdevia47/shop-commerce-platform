import { defineConfig } from 'tsup';

export default defineConfig({
  // Operator CLIs ship in the image: docker compose exec tenant node dist/client.js ...
  entry: { main: 'src/main.ts', client: 'scripts/client.ts' },
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
