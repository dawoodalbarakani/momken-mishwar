# Codebase Concerns

## Core Sections (Required)

### 1) Top Risks (Prioritized)

| Severity | Concern | Evidence | Impact | Suggested action |
|----------|---------|----------|--------|------------------|
| High | Dual parallel backend implementations (`apps/api` NestJS and `api_go` Go) | `api_go/README.md:3`, `apps/api/package.json` | High risk of domain divergence, split maintenance burden, and double effort | Clarify architectural target: align whether Go backend will fully replace NestJS or if NestJS remains the primary API (`[ASK USER]`) |
| High | Mobile Flutter apps un-executed locally | `README.md:17-18`, `docs/testing.md:24` | Runtime mobile behavior (GPS geolocator, maps, WebSocket drops) remains unverified in physical environments | Set up local Flutter SDK or containerized test environment to run integration tests |
| Medium | External service adapters are currently stubs | `.env.example:406,415`, `docs/deployment.md:19-22` | Cannot verify real SMS OTP delivery in Yemen, mapping coverage in Sana'a, or S3 uploads | Select and contract telecom OTP aggregator and mapping provider for Yemeni market |
| Medium | Real-time WebSocket Gateway not completed | `README.md:29`, `docs/architecture.md:78` | Ride updates currently rely on HTTP polling instead of low-latency socket pushes | Complete WebSocket Gateway implementation in NestJS or Go and wire with Flutter clients |

### 2) Technical Debt

List the most important debt items only.

| Debt item | Why it exists | Where | Risk if ignored | Suggested fix |
|-----------|---------------|-------|-----------------|---------------|
| Rate limiter table unbounded growth | `otp_request_limits` records each IP/phone rate limit window | `database/migrations/0003_otp_request_limits.sql`, `api_go/internal/modules/identity/adapters/postgres/otp_request_limiter.go:44` | Table bloat degrades query latency over time | Add scheduled retention cron/worker to purge expired rate limit rows |
| Hardcoded dummy seed parameters | Reference seeds contain fictional Sana'a boundaries and fares | `database/seeds/001_reference_data.sql`, `docs/deployment.md:24,26` | Operating with inaccurate pricing and geometric approximations | Replace rectangular boundary with real Sana'a GeoJSON boundary and market fares |
| Mixed package managers | Root & API use `pnpm`, while Admin Web uses `npm` | `package.json`, `apps/admin_web/package.json` | Divergent lockfile resolution and redundant `node_modules` caches | Migrate `apps/admin_web` to pnpm monorepo workspace |

### 3) Security Concerns

| Risk | OWASP category (if applicable) | Evidence | Current mitigation | Gap |
|------|--------------------------------|----------|--------------------|-----|
| SMS OTP Flooding / Cost Exhaustion | A04:2021 (Insecure Design) | `database/migrations/0003_otp_request_limits.sql` | Transactional phone and IP rate limiting with HMAC-hashed identifiers in Go | Shared rate limiter needs full wiring into HTTP entry points before public exposure |
| In-Memory Dev OTP in Production | A05:2021 (Security Misconfiguration) | `docs/security.md:15`, `.env.example:406` | Startup guard rejects `OTP_PROVIDER=console` when `NODE_ENV=production` | Must be strictly validated in CI deployment scripts |
| Refresh Token Theft / Replay | A07:2021 (Identification and Authentication Failures) | `api_go/internal/modules/identity/adapters/postgres/refresh_token_repository.go` | Token family revocation on reuse; SHA-256 hash stored at rest | Integration test required verifying concurrent reuse invalidates family |
| Direct DB Exposure | A05:2021 (Security Misconfiguration) | `infrastructure/docker/docker-compose.yml:16` | Ports bound to `127.0.0.1` locally | Ensure production ingress strictly isolates PostgreSQL behind private VPC |

### 4) Performance and Scaling Concerns

| Concern | Evidence | Current symptom | Scaling risk | Suggested improvement |
|---------|----------|-----------------|-------------|-----------------------|
| Database-driven Location Pings | `docs/adr/0003-redis-optional.md:4`, `database/migrations/0001_init_schema.sql:driver_location_updates` | Frequent location updates write directly to PostgreSQL | IOPS bottleneck and table bloat on high concurrent driver counts | Activate Redis profile (`docker-compose --profile redis`) to buffer ephemeral driver telemetry |
| Sequential Offer Sweeping | `apps/api/src/modules/dispatch/dispatch.service.ts` | Sweeper queries expired offers on polling interval | Search sweep latency increases as active ride count scales | Batch candidate queries with PostGIS indexed spatial filters |

### 5) Fragile/High-Churn Areas

| Area | Why fragile | Churn signal | Safe change strategy |
|------|-------------|-------------|----------------------|
| `apps/api/src/concurrency_scenarios.ts` | Orchestrates 8 multi-threaded database race conditions | 4 commits in recent history (`scan.py`) | Run against isolated `mishwar_test` (port 5433); never run against production DB |
| `apps/api/src/modules/dispatch/dispatch.service.ts` | Complex spatial query (`ST_DWithin`), candidate filtering, and atomic offer generation | 7 recent commits (`scan.py`) | Verify changes against both unit tests and concurrency scenarios |
| `api_go/internal/httpapi/auth_handlers.go` | Handles OTP challenge validation, JWT issuance, and rate limiting | 6 recent commits (`scan.py`) | Maintain rigorous unit and adapter test coverage (`auth_handlers_test.go`) |
| `.github/workflows/application-ci.yml` | Coordinates multi-service CI with PostGIS container services and pnpm lockfile | 8 recent commits (`scan.py`) | Test workflow edits carefully via branch push before merging |

### 6) `[ASK USER]` Questions

1. [ASK USER] What is the long-term plan for the dual backend: is `api_go` intended to completely replace `apps/api` (NestJS), or will they coexist for different services (e.g. Go for high-throughput tracking/dispatch, NestJS for back-office/admin APIs)?
2. [ASK USER] What SMS or WhatsApp gateway provider is targeted for Yemen (e.g., local telecom aggregator API), and what are the specific credentials or protocol requirements?
3. [ASK USER] Which map/routing provider will be deployed for Sana'a (Google Maps, Mapbox, or local OpenStreetMap / Valhalla tiles with landmarks support)?
4. [ASK USER] Should `apps/admin_web` be migrated into the root `pnpm-workspace.yaml` alongside `apps/api` to unify package management under `pnpm`?

### 7) Evidence

- `docs/codebase/.codebase-scan.txt` (High-churn files, commit history, TODOs)
- `README.md`
- `api_go/README.md`
- `docs/security.md`
- `docs/deployment.md`
- `docs/adr/0003-redis-optional.md`
- `apps/api/src/concurrency_scenarios.ts`
- `database/migrations/0003_otp_request_limits.sql`
