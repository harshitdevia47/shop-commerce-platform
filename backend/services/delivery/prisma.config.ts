import 'dotenv/config';
import { defineConfig } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  datasource: {
    // `prisma generate` does not need a database; commands that do will fail with a clear error.
    url: process.env.DATABASE_URL ?? '',
  },
});
