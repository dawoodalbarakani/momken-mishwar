# External Integrations

## Core Sections (Required)

### 1) Integration Inventory

| System | Type (API/DB/Queue/etc) | Purpose | Auth model | Criticality | Evidence |
|--------|---------------------------|---------|------------|-------------|----------|
| PostgreSQL + PostGIS | Relational DB & Spatial Store | Primary datastore for rides, users, spatial matching, ledger, and auditing | Username & password over TCP | Critical | `infrastructure/docker/docker-compose.yml:9`, `database/migrations/0001_init_schema.sql` |
| Redis (Optional) | In-memory key-value cache | High-throughput driver location ingestion and future pub/sub fanout | Password / URL connection string | Low (Optional in MVP) | `infrastructure/docker/docker-compose.yml:42`, `docs/adr/0003-redis-optional.md` |
| SMS / WhatsApp Provider | External Telephony API | Delivering 6-digit OTP verification challenges to Yemeni mobile numbers | API Key / Bearer token (Env var) | High | `.env.example:406`, `docs/deployment.md:19`, `api_go/README.md:46` |
| Maps & Geocoding Provider | Geospatial API | Route distance/duration calculation and reverse geocoding in Sana'a | API Key (`MAP_API_KEY`) | High | `.env.example:415-416`, `docs/deployment.md:20` |
| Firebase Cloud Messaging (FCM) | Push Notification Service | Delivering push notifications to offline or background mobile apps | Service Account JSON / Project ID (`FCM_PROJECT_ID`, `FCM_CREDENTIALS`) | Medium | `.env.example:413-414`, `docs/deployment.md:21` |
| S3-compatible Object Storage | Object Storage | Storing uploaded driver identity, license, and vehicle registration documents | S3 Access Key & Secret Key (`S3_ACCESS_KEY`, `S3_SECRET_KEY`) | Medium | `.env.example:409-412`, `docs/deployment.md:22` |

### 2) Data Stores

| Store | Role | Access layer | Key risk | Evidence |
|-------|------|--------------|----------|----------|
| `PostgreSQL 16` (`mishwar`) | Core system of record (31 tables, triggers, partial unique indexes) | Prisma 5.22, `pg` pool, `pgx/v5` (Go) | Connection pool exhaustion under concurrent location pings | `database/migrations/`, `apps/api/src/prisma/schema.prisma` |
| `PostgreSQL 16` (`mishwar_test`) | Isolated ephemeral test database for integration & concurrency suites | `pg` / `vitest` Supertest | Dirty state between parallel test suites if cleanup fails | `infrastructure/docker/docker-compose.yml:26`, `apps/api/src/concurrency_scenarios.ts:3` |
| `Redis 7` | Optional cache for ephemeral driver coordinates | Redis client (profile-gated in Docker Compose) | Data loss on restart (mitigated: location is transient, DB holds durable state) | `infrastructure/docker/docker-compose.yml:42`, `docs/adr/0003-redis-optional.md` |

### 3) Secrets and Credentials Handling

- Credential sources:
  - Repository contains only `.env.example` with dummy values.
  - Production credentials supplied via container environment variables from deployment secret stores.
- Hardcoding checks:
  - Passed: No API tokens, passwords, or production cryptographic keys committed in source.
  - Secrets like `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, and `START_CODE_SECRET` require minimum 32-byte high-entropy values in production.
- Rotation or lifecycle notes:
  - Refresh tokens employ automatic single-use rotation with token family tracking; reusing an invalidated token revokes the entire family (`api_go/README.md:15`, `database/migrations/0001_init_schema.sql:refresh_tokens`).

### 4) Reliability and Failure Behavior

- Retry/backoff behavior:
  - Mobile clients implement progressive exponential backoff on network failures while reusing the unique `Idempotency-Key` (`docs/architecture.md:81`).
- Timeout policy:
  - HTTP server request timeouts configured in Go and NestJS servers.
  - Offer TTL configured in `dispatch_settings.offer_ttl_seconds` (default 30–60s).
  - Search sweep timeout enforced by scheduled DB query (`search_timeout_seconds` -> transitions to `NO_DRIVER_FOUND`).
- Circuit-breaker or fallback behavior:
  - Offline fallback: When mobile connectivity drops, ride requests and status are stored locally in Secure Storage / SQLite cache and synchronized upon reconnection (`docs/superpowers/specs/2026-10-24-yemen-landmarks-offline-design.md:21`).
  - SMS fallback: `OTP_PROVIDER=console` acts as a developer fallback, rejecting startup if `NODE_ENV=production`.

### 5) Observability for Integrations

- Logging around external calls:
  - Structured request logging with execution duration via Pino (`pino-http`).
- Metrics/tracing coverage:
  - Health check endpoints (`/health/live` and `/health/ready`) probe PostgreSQL connectivity (`api_go/cmd/api/main.go`, `apps/api/src/modules/health/`).
- Missing visibility gaps:
  - Distributed tracing (e.g. OpenTelemetry / Jaeger) is not yet configured.
  - External APM dashboard and alerting integration are [TODO].

### 6) Evidence

- `infrastructure/docker/docker-compose.yml`
- `.env.example`
- `docs/deployment.md`
- `docs/architecture.md`
- `docs/adr/0003-redis-optional.md`
- `apps/api/src/prisma/schema.prisma`
- `database/migrations/0001_init_schema.sql`
