process.env.DATABASE_URL = process.env.DATABASE_TEST_URL ?? 'postgres://mishwar:mishwar_test_only@localhost:5433/mishwar_test';

// Keep integration tests deterministic: expiry is driven explicitly via
// POST /dispatch/sweep instead of a background timer firing mid-assertion.
process.env.DISPATCH_SWEEPER_ENABLED = 'false';
