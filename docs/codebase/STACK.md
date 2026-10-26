# Technology Stack

## Core Sections (Required)

### 1) Runtime Summary

| Area | Value | Evidence |
|------|-------|----------|
| Primary language | TypeScript (Backend & Admin), Go (Parallel API), Dart (Mobile), SQL (PostgreSQL Migrations) | `package.json`, `api_go/go.mod`, `apps/rider_app/pubspec.yaml`, `database/migrations/0001_init_schema.sql` |
| Runtime + version | Node.js `>=22`, Go `1.23`, Flutter `>=3.16.0` (Dart SDK `>=3.0.0 <4.0.0`), PostgreSQL `16` with PostGIS `3.4` | `package.json:304`, `api_go/go.mod:3`, `apps/driver_app/pubspec.yaml:5-7`, `infrastructure/docker/docker-compose.yml:10` |
| Package manager | `pnpm` (version `10.18.3` for monorepo and API), `npm` (for `apps/admin_web`), `pub` (for Flutter), `go mod` (for `api_go`) | `package.json:295`, `pnpm-workspace.yaml`, `apps/admin_web/package.json`, `api_go/go.mod` |
| Module/build system | ES Modules (`"type": "module"` in `apps/api`), Next.js App Router (`apps/admin_web`), Go standard compiler, Flutter build runner | `apps/api/package.json:62`, `apps/admin_web/package.json:8`, `api_go/Dockerfile`, `apps/rider_app/pubspec.yaml:31` |

### 2) Production Frameworks and Dependencies

List only high-impact production dependencies (frameworks, data, transport, auth).

| Dependency | Version | Role in system | Evidence |
|------------|---------|----------------|----------|
| `@nestjs/core`, `@nestjs/common` | `^12.0.0`, `^12.2.0` | Core backend modular web framework and dependency injection container | `apps/api/package.json:24-26` |
| `@prisma/client` | `5.22.0` | Relational database client and query builder | `apps/api/package.json:34` |
| `pg` | `^8.16.0` | PostgreSQL client for raw transactional queries and concurrency operations | `apps/api/package.json:38` |
| `github.com/jackc/pgx/v5` | `v5.7.2` | High-performance PostgreSQL driver and connection pooling for Go API | `api_go/go.mod:5` |
| `@nestjs/jwt`, `passport` | `^12.0.0`, `^0.7.0` | JWT authentication, bearer strategy, and access token validation | `apps/api/package.json:27-28` |
| `@nestjs/websockets`, `socket.io` | `^12.0.0` | Real-time event transport for ride status and dispatch updates | `apps/api/package.json:30,33` |
| `next` | `^15.0.0` | React web framework for back-office administration panel | `apps/admin_web/package.json:14` |
| `react`, `react-dom` | `^19.0.0` | Frontend UI rendering library for administrative web portal | `apps/admin_web/package.json:15-16` |
| `flutter_riverpod` | `^2.5.1` | Reactive state management for Flutter rider and driver apps | `apps/rider_app/pubspec.yaml:15` |
| `go_router` | `^14.0.0` | Declarative routing and deep linking in Flutter apps | `apps/rider_app/pubspec.yaml:16` |
| `dio` | `^5.4.0` | HTTP client with interceptors for mobile client API calls | `apps/rider_app/pubspec.yaml:17` |
| `flutter_secure_storage` | `^9.0.0` | Encrypted storage for access/refresh tokens on mobile devices | `apps/rider_app/pubspec.yaml:18` |
| `pino`, `pino-http` | `^9.6.0`, `^10.3.0` | Fast structured JSON logging for NestJS application | `apps/api/package.json:39-40` |
| `zod` | `^4.6.7` (API), `^3.23.0` (Web) | Runtime schema validation and data parsing | `apps/api/package.json:44`, `apps/admin_web/package.json:21` |

### 3) Development Toolchain

| Tool | Purpose | Evidence |
|------|---------|----------|
| `typescript` (v6.0.3 / v5.6.0) | Strict static type checking across API and Admin Web | `apps/api/package.json:59`, `apps/admin_web/package.json:25` |
| `vitest` (v5.0.5) + `supertest` | Fast unit and HTTP integration testing against PostgreSQL | `apps/api/package.json:60`, `docs/testing.md:14` |
| `tsx` (v4.21.0) | Direct TypeScript execution for domain unit tests (`node:test`) and concurrency runner | `apps/api/package.json:58`, `apps/api/package.json:11` |
| `tailwindcss` (v3.4.0) | Utility-first CSS styling for Next.js admin portal | `apps/admin_web/package.json:29` |
| `flutter_lints` | Official Dart/Flutter linting rules | `apps/rider_app/pubspec.yaml:27` |
| `gofmt`, `go vet` | Go standard code formatting and static analysis validation | `.github/workflows/go-api-ci.yml:38,47` |
| `docker compose` | Multi-container local infrastructure (PostgreSQL PostGIS and optional Redis) | `infrastructure/docker/docker-compose.yml` |

### 4) Key Commands

```bash
# Monorepo and dependency installation
pnpm install
cd apps/admin_web && npm install
cd api_go && go mod tidy

# Start local PostgreSQL and test databases
docker compose -f infrastructure/docker/docker-compose.yml up -d db db_test

# Apply SQL migrations and reference seed
DATABASE_URL=postgres://mishwar:mishwar_dev_only@localhost:5432/mishwar ./database/run-migrations.sh
psql "postgres://mishwar:mishwar_dev_only@localhost:5432/mishwar" -v ON_ERROR_STOP=1 -f database/seeds/001_reference_data.sql

# Backend typecheck, build, and tests
pnpm --filter @mishwar/api run typecheck
pnpm --filter @mishwar/api run build
pnpm --filter @mishwar/api run test:domain
pnpm --filter @mishwar/api test
pnpm --filter @mishwar/api exec tsx src/concurrency_scenarios.ts

# Go backend test and format verification
cd api_go && go test ./...
cd api_go && go vet ./...

# Admin Web typecheck and build
cd apps/admin_web && npm run typecheck
cd apps/admin_web && npm run build
```

### 5) Environment and Config

- Config sources: `.env.example`, `apps/admin_web/.env.example`, `.env` (sourced by `run-migrations.sh` and `@nestjs/config`).
- Required env vars:
  - Database: `DATABASE_URL`, `DATABASE_TEST_URL`
  - Server: `NODE_ENV`, `PORT` (default 4000), `CORS_ORIGIN`
  - Auth: `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `START_CODE_SECRET`
  - External adapters: `OTP_PROVIDER` (e.g. `console`), `OTP_DEV_DISPLAY`, `REDIS_URL`, `MAP_PROVIDER` (`stub`), `MAP_API_KEY`, `S3_ENDPOINT`, `S3_BUCKET`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `FCM_PROJECT_ID`, `FCM_CREDENTIALS`
- Deployment/runtime constraints:
  - Production requires PostgreSQL 16+ with PostGIS extension enabled.
  - `NODE_ENV=production` prohibits `OTP_PROVIDER=console` or test seed data.
  - Cash-only payment flows enforced; electronic payment gateways deferred.

### 6) Evidence

- `package.json`
- `pnpm-workspace.yaml`
- `apps/api/package.json`
- `apps/admin_web/package.json`
- `apps/driver_app/pubspec.yaml`
- `apps/rider_app/pubspec.yaml`
- `api_go/go.mod`
- `infrastructure/docker/docker-compose.yml`
- `.env.example`
- `.github/workflows/application-ci.yml`
