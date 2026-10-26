# Architecture

## Core Sections (Required)

### 1) Architectural Style

- Primary style: Modular Monolith with Clean / Hexagonal (Ports & Adapters) boundaries and Domain-Driven Design (DDD).
- Why this classification:
  - The backend is deployed as a single unified service (`apps/api`), but strictly isolates pure domain logic (`src/domain/`) from framework controllers and database adapters (`src/modules/`).
  - The parallel Go implementation (`api_go`) also enforces a modular monolith with explicit ports, adapters, and domain packages (`internal/modules/identity/`).
  - All database state mutations are governed by relational constraints, database triggers, and conditional update transactions rather than distributed services.
- Primary constraints:
  - PostgreSQL is the single source of truth for ride status and dispatch state (ADR-0004).
  - Server alone calculates pricing and snapshots immutable breakdowns on quotes and rides (ADR-0005).
  - Pure domain core must remain testable without dependencies or network (`src/domain/`).

### 2) System Flow

```text
[Rider App] -> [REST API /quotes] -> [Domain Pricing Engine] -> [Quoted Breakdown Snapshot]
      |
      v
[REST API POST /rides] -> [PostgreSQL (status: SEARCHING)] -> [Dispatch Sweeper ST_DWithin]
      |
      v
[Ride Offer (TTL)] -> [Driver App ACCEPT] -> [Atomic DB Txn: Conditional UPDATE rides + ACCEPT offer]
      |
      v
[HMAC Start Code Generated] -> [Driver En-Route & Arrived] -> [Driver POST /start with 4-Digit Code]
      |
      v
[Constant-time HMAC Verification] -> [Ride IN_PROGRESS] -> [POST /complete] -> [Append-Only Driver Ledger]
```

Step-by-step trace backed by source files:
1. Ride Quote: Rider app submits coordinates via `POST /quotes`. `PricingService` executes `calculateQuote()` (`apps/api/src/domain/pricing.ts`), querying active `pricing_rules`. Returns an immutable JSON breakdown (`base_fare`, `distance_fare`, `time_fare`, `min_fare`, `currency_code`).
2. Ride Creation: Rider creates a ride via `POST /rides` with an `Idempotency-Key`. `RideRequestsService` verifies customer status and inserts into `rides` with status `SEARCHING` and the snapshotted price breakdown (`apps/api/src/modules/ride-requests/`).
3. Driver Dispatch: `DispatchService` queries nearby approved, online drivers using PostGIS `ST_DWithin` (`apps/api/src/modules/dispatch/dispatch.service.ts`), generating `ride_offers` with a short expiration TTL.
4. Atomic Assignment: Driver accepts via `POST /offers/{id}/accept`. `TripsService` runs a PostgreSQL transaction performing a conditional update (`UPDATE rides SET status = 'ASSIGNED', driver_id = $driver WHERE id = $ride AND status = 'SEARCHING' AND driver_id IS NULL`). The database trigger and partial unique indexes guarantee exactly one winning driver (`docs/adr/0004-atomic-assignment-in-postgres.md`).
5. Ride Start Verification: A 4-digit code is generated via HMAC-SHA256 from `(ride_id, nonce)` using `START_CODE_SECRET` (`apps/api/src/domain/start-code.ts`). Rider shows the code; driver submits it to `POST /rides/{id}/start`. Verified in constant time; status moves to `IN_PROGRESS`.
6. Completion & Settlement: Driver finishes the trip via `POST /rides/{id}/complete`. Cash payment is recorded; driver earnings and platform commission are written to append-only `driver_ledger_entries` (`apps/api/src/domain/ledger.ts`, `docs/adr/0005-money-representation.md`).

### 3) Layer/Module Responsibilities

| Layer or module | Owns | Must not own | Evidence |
|-----------------|------|--------------|----------|
| `apps/api/src/domain/` | Pure pricing calculations, state transitions, money arithmetic, ledger balance invariants, start-code HMAC | Direct DB access, framework routing, HTTP responses, or ORM annotations | `apps/api/src/domain/pricing.ts`, `ride-state.ts`, `ledger.ts` |
| `apps/api/src/modules/trips/` | Ride lifecycle progression (`ASSIGNED` -> `EN_ROUTE` -> `ARRIVED` -> `IN_PROGRESS` -> `COMPLETED`) | Financial ledger calculations (must delegate to `DriverWalletModule`) | `apps/api/src/modules/trips/trips.service.ts` |
| `apps/api/src/modules/dispatch/` | Driver candidate search (`ST_DWithin`), offer batch creation, offer expiry sweeps | Directly modifying customer ride status outside state machine | `apps/api/src/modules/dispatch/dispatch.service.ts` |
| `apps/api/src/modules/driver-wallet/` | Append-only ledger entries (`driver_ledger_entries`), payout approval checks | Modifying ride core properties or driver verification statuses | `apps/api/src/modules/driver-wallet/driver-wallet.service.ts` |
| `database/migrations/` | Schema tables, PostGIS GiST indexes, DB trigger guards (`guard_ride_update`), immutability checks | Business logic pricing calculations or dynamic configuration | `database/migrations/0001_init_schema.sql`, `0002_integrity_guards.sql` |
| `api_go/internal/modules/identity/` | User repositories, OTP generation/validation, refresh token rotation, JWT access token service | Ride lifecycle or dispatch logic | `api_go/internal/modules/identity/` |

### 4) Reused Patterns

| Pattern | Where found | Why it exists |
|---------|-------------|---------------|
| Ports & Adapters (Hexagonal) | `api_go/internal/modules/identity/ports/`, `apps/api/src/modules/` | Decouples external services (SMS, maps, object storage) and database adapters from business domain |
| Idempotency Key | `apps/api/src/concurrency_scenarios.ts:256`, `database/migrations/0001_init_schema.sql:CREATE TABLE idempotency_keys` | Prevents duplicate mutations from network retries or repeated taps |
| Derived Ephemeral Nonce | `apps/api/src/domain/start-code.ts`, `docs/adr/0006-derived-start-code.md` | Derives 4-digit ride start code using HMAC so secrets are never stored in reversible plaintext in DB |
| Immutable Ledger | `apps/api/src/domain/ledger.ts`, `database/migrations/0001_init_schema.sql:driver_ledger_entries` | Financial records cannot be updated or deleted; adjustments must be append-only reversals |
| Conditional Atomic Updates | `apps/api/src/concurrency_scenarios.ts:216`, `docs/database-design.md:37` | Eliminates race conditions in driver acceptance without distributed locking |

### 5) Known Architectural Risks

- Split Backend Implementations: Maintaining both `apps/api` (NestJS) and `api_go` (Go) risks divergent behavior, split developer attention, and contract misalignment until a firm deprecation or migration milestone is achieved.
- Unimplemented Real-time Gateway: WebSocket gateway in NestJS is currently draft/stubbed; client fallbacks depend on HTTP polling (`GET /rides/active`), which creates scaling overhead under low connectivity.
- External Integration Stubs: Core integrations (SMS OTP delivery, Yemeni mapping/geocoding, S3 document storage, FCM push) are currently local console stubs; production readiness depends on real external provider contracts.

### 6) Evidence

- `docs/architecture.md`
- `docs/adr/0001-monorepo-and-stack.md`
- `docs/adr/0002-sql-first-migrations.md`
- `docs/adr/0003-redis-optional.md`
- `docs/adr/0004-atomic-assignment-in-postgres.md`
- `docs/adr/0005-money-representation.md`
- `docs/adr/0006-derived-start-code.md`
- `apps/api/src/domain/pricing.ts`
- `apps/api/src/domain/ride-state.ts`
- `apps/api/src/concurrency_scenarios.ts`
- `api_go/docs/ARCHITECTURE.md`
