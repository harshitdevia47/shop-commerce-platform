import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globalSetup: ['./test/global-setup.ts'],
    // Integration tests share one database.
    fileParallelism: false,
    env: {
      DATABASE_URL: process.env.TEST_DATABASE_URL ?? 'postgresql://qc:qc_dev_password@localhost:5433/qc_order_test',
      INTERNAL_HMAC_SECRET: 'test-internal-secret-test-internal-secret',
      LOG_LEVEL: 'silent',
    },
  },
});
