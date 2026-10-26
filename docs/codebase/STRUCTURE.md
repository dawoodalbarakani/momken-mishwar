# Codebase Structure

## Core Sections (Required)

### 1) Top-Level Map

List only meaningful top-level directories and files.

| Path | Purpose | Evidence |
|------|---------|----------|
| `apps/api/` | NestJS backend REST API, WebSocket transport, domain models, and DB integration | `apps/api/package.json`, `apps/api/src/main.ts` |
| `apps/admin_web/` | Next.js 15 back-office admin dashboard with RTL and Arabic UI | `apps/admin_web/package.json`, `apps/admin_web/app/` |
| `apps/rider_app/` | Flutter mobile client for riders/customers (booking, tracking, quotes) | `apps/rider_app/pubspec.yaml`, `apps/rider_app/lib/main.dart` |
| `apps/driver_app/` | Flutter mobile client for captains/drivers (offers, navigation, earnings) | `apps/driver_app/pubspec.yaml`, `apps/driver_app/lib/main.dart` |
| `api_go/` | High-performance Go modular monolith API implementation (parallel backend) | `api_go/go.mod`, `api_go/cmd/api/main.go`, `api_go/README.md` |
| `database/` | SQL migrations (`migrations/`), migration runner script, and reference seed data | `database/migrations/`, `database/run-migrations.sh`, `database/seeds/` |
| `infrastructure/` | Container orchestration configurations (Docker Compose for PostGIS & Redis) | `infrastructure/docker/docker-compose.yml` |
| `docs/` | System architecture, database design, API specification, testing, and ADR records | `docs/architecture.md`, `docs/database-design.md`, `docs/adr/` |
| `.github/workflows/` | Continuous integration workflows for API, PostgreSQL concurrency, Go, and Flutter | `.github/workflows/application-ci.yml`, `postgres-concurrency.yml` |
| `.agents/` | Agent skills, guidelines, instructions, and automated workflows | `.agents/skills/` |

### 2) Entry Points

- Main runtime entry: `apps/api/src/main.ts` (NestJS server initializing modules, validation pipes, Swagger docs, and listening on `PORT`).
- Secondary entry points:
  - Go API: `api_go/cmd/api/main.go`
  - Admin Web: `apps/admin_web/app/page.tsx` & `layout.tsx`
  - Rider Mobile App: `apps/rider_app/lib/main.dart`
  - Driver Mobile App: `apps/driver_app/lib/main.dart`
  - Database Migrations: `database/run-migrations.sh`
  - Concurrency Suite: `apps/api/src/concurrency_scenarios.ts`
- How entry is selected:
  - Monorepo package scripts in `package.json` and `Makefile` route to individual application entry points via `pnpm --filter` or `docker compose`.

### 3) Module Boundaries

| Boundary | What belongs here | What must not be here |
|----------|-------------------|------------------------|
| `apps/api/src/domain/` | Pure business logic, pricing math, ride state machines, ledger entries, HMAC start codes | Framework decorators, database queries, NestJS modules, or network calls |
| `apps/api/src/modules/` | NestJS controllers, services, DTOs, guards, and module wiring | Direct cross-module private database mutations (must call designated services) |
| `apps/api/src/prisma/` | Generated Prisma schema and database client reflection | Handcrafted schema migrations (migrations belong exclusively in `database/migrations/`) |
| `api_go/internal/modules/` | Domain logic, repository ports, postgres adapters, and services for Go API | Framework coupling, global state, or unvalidated DB mutations |
| `database/migrations/` | Versioned, idempotent SQL DDL/DML migrations and triggers (source of truth) | Dynamic application code or ORM-generated untracked schema changes |
| `apps/*_app/lib/domain/` | Entity models and pure state definitions for mobile apps | Direct HTTP calls, UI widgets, or device storage IO |
| `apps/*_app/lib/data/` | Repositories, REST API services (Dio), WebSocket handlers, secure storage | Flutter UI widgets or presentation layout |
| `apps/*_app/lib/ui/` | Riverpod providers, screens, widgets, themes, and presentation components | Direct database access or raw network calls |

### 4) Naming and Organization Rules

- File naming pattern:
  - TypeScript/NestJS: kebab-case with role suffix (`ride-requests.service.ts`, `auth.controller.ts`, `pricing.test.ts`).
  - Go: snake_case (`auth_handlers.go`, `otp_request_limiter.go`).
  - Dart: snake_case (`app_router.dart`, `otp_screen.dart`, `dio_client.dart`).
  - SQL: snake_case prefixed by 4-digit version (`0001_init_schema.sql`, `0002_integrity_guards.sql`).
- Directory organization pattern:
  - Backend NestJS: Feature module organization (`src/modules/<feature>/`) over a pure domain core (`src/domain/`).
  - Go Backend: Hexagonal / Clean Architecture layout (`internal/modules/<domain>/[domain, ports, adapters, service]`).
  - Mobile Apps: Layered architecture (`lib/core/`, `lib/domain/`, `lib/data/`, `lib/ui/`, `lib/l10n/`).
  - Admin Web: Next.js 15 App Router (`app/<route>/`, `components/`, `lib/`).
- Import aliasing or path conventions:
  - `apps/admin_web` uses `@/*` mapping to root (`tsconfig.json:paths`).
  - NestJS uses relative module imports (`./domain/...`, `../common/...`).
  - Flutter uses package imports (`package:rider_app/...`, `package:driver_app/...`).

### 5) Evidence

- `apps/api/src/main.ts`
- `apps/api/src/domain/`
- `apps/api/src/modules/`
- `api_go/cmd/api/main.go`
- `apps/rider_app/lib/`
- `apps/driver_app/lib/`
- `apps/admin_web/app/`
- `database/migrations/`
- `tsconfig.json`
- `Makefile`
