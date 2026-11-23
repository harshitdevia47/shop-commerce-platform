import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    env: {
      INTERNAL_HMAC_SECRET: 'test-internal-secret-test-internal-secret',
      LOG_LEVEL: 'silent',
    },
  },
});
