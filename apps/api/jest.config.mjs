export default {
  rootDir: '.',
  testMatch: ["**/*.integration.test.ts", "**/*.e2e.test.ts"],
  transform: {
    "^.+\\.ts$": ["ts-jest", { useESM: true }],
  },
  testEnvironment: "node",
  setupFiles: ["<rootDir>/src/test-setup.ts"],
  moduleNameMapper: {
    "^(\\.\\.?/.*\\.[tj]s)$": "$1",
  },
};
