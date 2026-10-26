# Testing Patterns

## Core Sections (Required)

### 1) Test Stack and Commands

- Primary test framework:
  - Node.js built-in test runner (`node:test` via `tsx`) for pure domain unit tests.
  - `vitest` (v5.0.5) + `supertest` (v7.3.1) for API integration testing.
  - Go standard `testing` package (`go test`) for `api_go`.
  - `flutter_test` for mobile apps.
- Assertion/mocking tools:
  - `vitest` assertions and Supertest HTTP expectations.
  - Direct PostgreSQL assertions in raw `pg` concurrency suite.
  - `mockito` in Flutter apps.
- Commands:

```bash
# Run pure domain unit tests (35 tests, zero dependencies)
pnpm --filter @mishwar/api run test:domain

# Run API HTTP integration tests against mishwar_test
pnpm --filter @mishwar/api test

# Run PostgreSQL real concurrency integration scenarios (8 scenarios)
pnpm --filter @mishwar/api exec tsx src/concurrency_scenarios.ts

# Run Go backend unit & adapter tests
cd api_go && go test -v ./...

# Run admin web typecheck
cd apps/admin_web && npm run typecheck
```

### 2) Test Layout

- Test file placement pattern:
  - Pure domain unit tests: Co-located in `apps/api/src/domain/` (`pricing.test.ts`, `ride-state.test.ts`, `ledger.test.ts`, `start-code.test.ts`, `money.test.ts`).
  - Integration tests: Co-located or placed in `src/` (`apps/api/src/app.integration.test.ts`).
  - Concurrency scenarios: Dedicated test harness file `apps/api/src/concurrency_scenarios.ts`.
  - Go tests: Co-located in corresponding Go packages (`auth_handlers_test.go`, `otp_service_test.go`).
- Naming convention:
  - TypeScript: `*.test.ts`.
  - Go: `*_test.go`.
  - Dart: `*_test.dart`.
- Setup files and where they run:
  - `apps/api/src/test-setup.ts` initializes testing environment variables before Vitest executes.
  - `database/run-migrations.sh` applies migrations to `db_test` before running CI test jobs.

### 3) Test Scope Matrix

| Scope | Covered? | Typical target | Notes |
|-------|----------|----------------|-------|
| Unit (Domain Core) | Yes | Pricing, Ride State, Money arithmetic, Start Code HMAC, Ledger invariants | 35 tests passing; executes in <100ms with zero network or DB dependencies (`docs/testing.md:12`) |
| Integration (HTTP/DB) | Yes | Auth endpoints, ride creation, status queries via Supertest against PostgreSQL | 3 integration tests passing against `mishwar_test` (port 5433) (`docs/testing.md:8`) |
| Concurrency (DB Transactions) | Yes | Race conditions: double offer accept, conflicting driver acceptance, duplicate idempotency keys, expired offer accept | 8 scenarios passing with real PostgreSQL `pg` pool (`apps/api/src/concurrency_scenarios.ts`) |
| Mobile E2E / UI | No | Flutter rider and driver screens | Stubs created; marked un-executed due to missing local Flutter SDK (`README.md:17-18`) |
| Web Portal Integration | Partial | Admin Web typecheck and production build verification | `next build` passes in CI (`.github/workflows/application-ci.yml:182`) |

### 4) Mocking and Isolation Strategy

- Main mocking approach:
  - Domain tests: Zero mocking. Deterministic pure functions with exact input/output verification.
  - Concurrency tests: Zero mocking. Real database transactions using PostgreSQL connection pool against isolated `mishwar_test`.
  - External adapters: Ports & adapters interfaces allow swapping SMS and map providers with mock stubs during test execution.
- Isolation guarantees:
  - Test database `db_test` runs on port 5433 with dedicated `mishwar_test` database (backed by `tmpfs` in Docker Compose, wiped on restart).
  - Concurrency runner explicitly runs teardown SQL cleanup queries (`cleanupRideSql`) after each scenario.
- Common failure mode in tests:
  - Attempting to run integration or concurrency tests without PostgreSQL running on port 5433.

### 5) Coverage and Quality Signals

- Coverage tool + threshold:
  - Vitest coverage configured via `pnpm --filter @mishwar/api run test:cov` (using `@vitest/coverage-v8`).
- Current reported coverage:
  - Pure domain core (`src/domain/`): ~100% path coverage for pricing, state transitions, ledger, and HMAC start code.
  - Full API endpoints coverage: [TODO] (planned expansion for additional REST endpoints).
- Known gaps/flaky areas:
  - Flutter apps require running on physical/virtual mobile devices to validate GPS tracking and WebSocket reconnection under weak network conditions.

### 6) Evidence

- `apps/api/src/domain/*.test.ts`
- `apps/api/src/app.integration.test.ts`
- `apps/api/src/concurrency_scenarios.ts`
- `apps/api/package.json:11-14`
- `api_go/internal/httpapi/auth_handlers_test.go`
- `docs/testing.md`
- `.github/workflows/application-ci.yml`
- `.github/workflows/postgres-concurrency.yml`
