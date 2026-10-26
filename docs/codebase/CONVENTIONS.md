# Coding Conventions

## Core Sections (Required)

### 1) Naming Rules

| Item | Rule | Example | Evidence |
|------|------|---------|----------|
| Files (TypeScript) | kebab-case with descriptive domain or role suffix | `ride-requests.service.ts`, `pricing.test.ts`, `app.module.ts` | `apps/api/src/modules/ride-requests/` |
| Files (Go) | snake_case, tests suffixed with `_test.go` | `auth_handlers.go`, `otp_request_limiter_test.go` | `api_go/internal/httpapi/` |
| Files (Dart) | snake_case, tests suffixed with `_test.dart` | `app_router.dart`, `otp_screen.dart`, `app_theme.dart` | `apps/driver_app/lib/ui/` |
| Files (SQL) | 4-digit version prefix + snake_case description | `0001_init_schema.sql`, `0002_integrity_guards.sql` | `database/migrations/` |
| Functions/methods | camelCase (TS/Dart), PascalCase for exported / camelCase for unexported (Go), snake_case (SQL) | `calculateQuote`, `applyTransition`, `NewRouter`, `guard_ride_update` | `apps/api/src/domain/pricing.ts`, `api_go/internal/httpapi/router.go` |
| Types/interfaces | PascalCase (TS/Go/Dart) | `PricingRule`, `RideOffer`, `OtpChallenge`, `RefreshToken` | `apps/api/src/domain/pricing.ts`, `api_go/internal/modules/identity/domain/` |
| Constants/env vars | UPPER_SNAKE_CASE | `DATABASE_URL`, `JWT_ACCESS_SECRET`, `START_CODE_SECRET` | `.env.example`, `apps/api/src/concurrency_scenarios.ts:7` |

### 2) Formatting and Linting

- Formatter:
  - TypeScript: Standard Prettier / ESLint integration.
  - Go: `gofmt` (enforced via `.github/workflows/go-api-ci.yml:38`).
  - Dart: `dart format` / Flutter standard formatting.
- Linter:
  - TypeScript: `tsc --noEmit` in strict mode (`tsconfig.json: "strict": true, "noImplicitAny": true`).
  - Next.js: `next lint` (ESLint 9).
  - Flutter: `flutter_lints` specified in `pubspec.yaml:27`.
  - Go: `go vet` (enforced via `.github/workflows/go-api-ci.yml:47`).
- Most relevant enforced rules:
  1. Strict null checks and explicit return types in TypeScript (`tsconfig.json`).
  2. Formatting compliance required in CI: zero unformatted Go files permitted (`gofmt -l`).
  3. No mutable global singletons for business state; database transactions must be clean and explicitly closed.
- Run commands:
  - `pnpm --filter @mishwar/api run typecheck`
  - `cd apps/admin_web && npm run typecheck && npm run lint`
  - `cd api_go && go fmt ./... && go vet ./...`

### 3) Import and Module Conventions

- Import grouping/order:
  - TypeScript: External framework packages (`@nestjs/...`, `rxjs`), followed by internal core/domain modules (`../../domain/...`), followed by local utilities and interfaces.
  - Go: Standard library imports first, empty line, followed by third-party packages (`github.com/...`), followed by internal module packages.
  - Dart: Flutter SDK imports (`package:flutter/...`), third-party packages (`package:flutter_riverpod/...`), followed by project package imports (`package:driver_app/...`).
- Alias vs relative import policy:
  - `apps/admin_web` uses path alias `@/*` (`tsconfig.json`).
  - `apps/api` uses explicit relative paths (`./domain/pricing.js`, `../common/...`).
- Public exports/barrel policy:
  - NestJS modules encapsulate their internal services and export only designated providers through the `@Module({ exports: [...] })` decorator.

### 4) Error and Logging Conventions

- Error strategy by layer:
  - Domain Layer: Throws typed error codes or returns typed result objects (`{ ok: false, error: 'INSUFFICIENT_FUNDS' }`).
  - Service Layer: Catches domain errors and maps them to appropriate NestJS HTTP exceptions (`ConflictException`, `BadRequestException`, `NotFoundException`).
  - API Wire Format: Standardized JSON envelope:
    ```json
    {
      "error": {
        "code": "RIDE_ALREADY_ASSIGNED",
        "message_ar": "الرحلة مسندة لسائق آخر بالفعل",
        "message_en": "Ride is already assigned to another driver",
        "request_id": "req-12345"
      }
    }
    ```
- Logging style and required context fields:
  - Pino structured JSON logging (`pino`, `pino-http`).
  - Required fields in log lines: `timestamp`, `level`, `req.id` (correlation ID), `method`, `url`, `durationMs`.
- Sensitive-data redaction rules:
  - Passwords, OTP codes, HMAC secrets, refresh tokens, and credit values must never be logged. Phone numbers and IP addresses are masked or hashed with HMAC before indexing (`api_go/internal/modules/identity/adapters/postgres/otp_request_limiter.go`).

### 5) Testing Conventions

- Test file naming/location rule:
  - Pure domain unit tests: co-located alongside source with `*.test.ts` extension (`apps/api/src/domain/ledger.test.ts`).
  - Integration tests: located in `src/integration/` or named `*.integration.test.ts` (`apps/api/src/app.integration.test.ts`).
  - Concurrency tests: dedicated scenario harness (`apps/api/src/concurrency_scenarios.ts`).
  - Go tests: co-located with source with `*_test.go` suffix.
- Mocking strategy norm:
  - Pure domain tests avoid mocks completely (pure inputs -> pure outputs).
  - NestJS integration tests utilize real PostgreSQL database containers (`mishwar_test` on port 5433) rather than SQLite or in-memory DBs to guarantee PostGIS and trigger fidelity.
  - External network services (SMS, maps, FCM) mocked via ports/adapters.
- Coverage expectation:
  - Domain core maintains 100% test coverage over pricing math, money integer conversions, and state machines (`docs/testing.md:12`).

### 6) Evidence

- `apps/api/package.json`
- `apps/api/tsconfig.json`
- `apps/admin_web/package.json`
- `apps/admin_web/tsconfig.json`
- `apps/rider_app/pubspec.yaml`
- `apps/driver_app/pubspec.yaml`
- `api_go/internal/httpapi/router.go`
- `.github/workflows/go-api-ci.yml`
- `docs/api-specification.md:12`
- `docs/testing.md`
