# api_go — Mishwar Yemen Go API

This directory contains a Go implementation that ports the business capabilities of the existing TypeScript API (`apps/api`) while preserving the documented API contract. It uses the same PostgreSQL schema and migrations as the TypeScript API.

## Included

- Go HTTP server with bounded timeouts, graceful shutdown, request IDs, and panic recovery.
- PostgreSQL pool using pgx/v5, with connection validation at startup.
- Liveness (`GET /health/live`) and readiness (`GET /health/ready`) endpoints.
- JSON API entrypoint at `GET /api/v1`.
- Environment-based configuration with validation at startup.
- **Identity/auth**: OTP request/verify, access + refresh tokens, rotation, logout, bearer middleware.
- **Rides**: create, get, active-by-customer, cancel (server-verified fare, idempotent creation).
- **Dispatch**: driver search with PostGIS proximity, offer creation, atomic offer acceptance with ride assignment + start-code nonce, sweep.
- **Trips**: en-route, arrived, start (server-verified start code), complete (with cash settlement ledger entries).
- **Drivers**: profile, availability, vehicle registration, list (admin).
- **Customers**: profile, saved places.
- **Payments**: cash payment recording, list, driver payout requests, payout approval (four-eyes), driver balance from ledger.
- **Driver locations**: batch updates, latest location with age.
- **Admin**: driver/ride/payout/pricing-rule listing, staff ride cancellation, payout approval, driver balances, dashboard stats.
- **Pricing**: server-computed fare quotes from PostgreSQL pricing rules via PostGIS distance, with money in integer minor units (no floating-point for money).
- **Domain**: ride-state transition machine, start-code HMAC derivation/verification, ledger entry builder with balance invariant, pricing engine with DISTANCE_TIME / FIXED_ROUTE / MANUAL modes.

## Run locally

```sh
# 1. Start PostgreSQL (PostGIS) on port 5432 with the mishwar database
docker compose -f infrastructure/docker/docker-compose.yml up -d db

# 2. Apply migrations and seed data
cd /workspaces/momken-mishwar
docker exec mishwar-dev-db-1 psql -U mishwar -d mishwar -v ON_ERROR_STOP=1 -f - < database/migrations/0001_init_schema.sql
docker exec mishwar-dev-db-1 psql -U mishwar -d mishwar -v ON_ERROR_STOP=1 -f - < database/migrations/0002_integrity_guards.sql
docker exec mishwar-dev-db-1 psql -U mishwar -d mishwar -v ON_ERROR_STOP=1 -f - < database/migrations/0003_otp_request_limits.sql
docker cp database/seeds/001_reference_data.sql mishwar-dev-db-1:/tmp/seed.sql
docker exec mishwar-dev-db-1 psql -U mishwar -d mishwar -v ON_ERROR_STOP=1 -f /tmp/seed.sql

# 3. Configure and run the Go API
cd api_go
cp .env.example .env
set -a; . ./.env; set +a
go mod tidy
go test ./...
go vet ./...
golangci-lint run ./...
go run ./cmd/api
```

- `GET /health/live`: process liveness; no database dependency.
- `GET /health/ready`: checks PostgreSQL connectivity.
- `GET /api/v1`: service metadata.
- `GET /api/v1/openapi.yaml`: OpenAPI 3.0 contract (YAML).
- `GET /docs/swagger`: Swagger UI backed by the OpenAPI contract.
- `GET /docs/redoc`: ReDoc backed by the OpenAPI contract.
- `GET /docs`: redirects to Swagger UI.

## Authentication endpoints

- `POST /api/v1/auth/otp/request`: request a single-use OTP (console provider in dev).
- `POST /api/v1/auth/otp/verify`: verify OTP and issue access + refresh tokens.
- `POST /api/v1/auth/refresh`: rotate refresh token and issue a new token pair.
- `POST /api/v1/auth/logout`: revoke refresh token family (requires Bearer JWT).
- `GET /api/v1/auth/me`: retrieve authenticated user profile (requires Bearer JWT).

## Business endpoints (versioned under /api/v1)

All business endpoints require a valid Bearer access token and enforce server-side role-based authorization.

**Rides:**
- `POST /rides` — create a ride (idempotent via `Idempotency-Key` header)
- `GET /rides/active` — customer's active ride
- `GET /rides/{id}` — ride detail
- `POST /rides/{id}/cancel` — customer cancels their ride

**Dispatch (SYSTEM/ADMIN roles):**
- `POST /dispatch/rides/{rideId}/search` — create driver offers
- `POST /dispatch/offers/{offerId}/accept` — driver accepts an offer (assigns ride + start code)
- `POST /dispatch/sweep` — expire pending offers and timed-out searches

**Trips (DRIVER role):**
- `POST /rides/{id}/en-route` — driver en route to pickup
- `POST /rides/{id}/arrived` — driver arrived at pickup
- `POST /rides/{id}/start` — start trip (requires verified start code)
- `POST /rides/{id}/complete` — complete trip + cash ledger settlement
- `GET /rides/{id}/start-code` — customer retrieves start code (display to driver)

**Drivers:**
- `GET /drivers/me/profile` — driver profile
- `POST /drivers/me/availability` — set online/offline
- `GET /drivers` — list drivers (admin/staff)
- `POST /vehicles` — register vehicle
- `GET /vehicles/me` — driver's vehicles

**Customers:**
- `GET /customers/me/profile` — get or create profile
- `GET /customers/me/saved-places` — list saved places
- `POST /customers/me/saved-places` — add saved place

**Payments & Wallet:**
- `POST /payments/rides/{rideId}` — record cash payment
- `GET /payments` — list payments (finance/admin)
- `POST /driver/payout-requests` — request driver payout
- `GET /driver/earnings` — driver balance
- `GET /driver/ledger` — driver ledger entries
- `POST /admin/payouts/{id}/approve` — approve payout (four-eyes)
- `GET /admin/driver-balances` — all driver balances

**Locations (DRIVER role):**
- `POST /driver/location` — batch location updates
- `GET /driver/location/latest` — latest location with age

**Admin:**
- `GET /admin/drivers` — list drivers
- `GET /admin/rides` — list rides
- `POST /admin/rides/{id}/cancel` — staff cancels ride
- `GET /admin/pricing-rules` — list pricing rules
- `GET /admin/payouts` — list payouts
- `GET /admin/dashboard/stats` — dashboard statistics

## Architecture

```
cmd/api/              — entry point, dependency wiring, server lifecycle
internal/config/      — environment-based configuration with validation
internal/store/       — PostgreSQL connection pool
internal/domain/      — pure domain logic (money, pricing, ride_state, start_code, ledger)
internal/httpapi/     — HTTP layer: routing, middleware, auth handlers, API handlers
internal/modules/*/   — per-module ports (interfaces), service, and postgres adapters
```

All domain packages are pure Go with no I/O, keeping business rules testable without a database.

## Testing

```sh
go test ./...           # unit + package tests
go test -race ./...     # race-detector enabled
go vet ./...            # static analysis
golangci-lint run ./... # linting
```

## Security

- Passwords/tokens/secrets are never logged.
- OTP codes are stored as SHA-256 digests with a pepper.
- Refresh tokens are stored as SHA-256 digests; rotation revokes the old token and family revocation on reuse detection.
- Start codes are derived via HMAC-SHA256 and verified in constant time.
- Money uses `int64` minor units throughout; no floating-point for currency.
- Ride transitions use PostgreSQL row locks (`FOR UPDATE`) and conditional `UPDATE ... WHERE version = ?` for optimistic concurrency.
- All financial/ride mutations are transactional.
- `Idempotency-Key` header support for write endpoints.

Do not commit `.env` files containing real credentials.
