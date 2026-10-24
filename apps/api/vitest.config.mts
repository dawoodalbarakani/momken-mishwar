import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/*.integration.test.ts', 'src/**/*.e2e.test.ts'],
    setupFiles: ['./src/test-setup.ts'],
    environment: 'node',
    globals: true,
  },
});
