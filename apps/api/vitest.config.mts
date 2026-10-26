import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // `*.spec.ts` are the DB-free unit tests (mocked Prisma). They must be
    // listed here: `test:domain` only globs `src/domain/*.test.ts`, so without
    // this pattern the module specs exist but are never executed by any script.
    include: [
      'src/**/*.spec.ts',
      'src/**/*.integration.test.ts',
      'src/**/*.e2e.test.ts',
    ],
    setupFiles: ['./src/test-setup.ts'],
    environment: 'node',
    globals: true,
  },
});
