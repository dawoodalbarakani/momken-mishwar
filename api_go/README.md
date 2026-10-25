# api_go — Mishwar Yemen Go API

This directory starts a Go implementation alongside the existing API. It does not replace or change `apps/api`; port business behavior incrementally and preserve the documented API contract.

## Included

- Go HTTP server with bounded timeouts and graceful shutdown.
- PostgreSQL pool using pgx/v5, with connection validation at startup.
- Liveness and readiness endpoints.
- JSON panic recovery and a versioned API entrypoint.
- Environment-based configuration and a minimal container image.
- Identity domain types for user roles/status and OTP challenge lifecycle rules.
- PostgreSQL user repository against the existing `users` and `user_roles` tables.
- OTP repository against the existing `otp_challenges` table, including row-locked verification, persisted attempt increments, constant-time hash comparison, and one-time consumption.
- Refresh-token repository and service using opaque high-entropy secrets, SHA-256 digests at rest, transactional rotation, and family revocation on token reuse.

## Run locally

```sh
cp .env.example .env
# Ensure PostgreSQL is running and DATABASE_URL points to the Mishwar database.
set -a; . ./.env; set +a
go mod tidy
go test ./...
go run ./cmd/api
```

- `GET /health/live`: process liveness; no database dependency.
- `GET /health/ready`: checks PostgreSQL.
- `GET /api/v1`: service metadata.

## Identity module status

The identity foundations are under `internal/modules/identity`:

- `domain`: user roles/status and OTP challenge lifecycle invariants.
- `ports`: user and OTP repository interfaces.
- `adapters/postgres`: user/role lookups and OTP persistence/verification against the existing schema.
- `service`: cryptographically random six-digit OTP generation, keyed HMAC-SHA256 storage/verification, challenge expiry, and required rate-limiter/delivery interfaces. Unit tests cover service boundaries.

The OTP service requires a pepper of at least 32 bytes, a delivery adapter, and a rate limiter; it persists only keyed hashes and never returns the generated code to the API caller. Production must use a shared/distributed limiter, a real SMS/voice provider, and secrets from the deployment secret store. OTP request/verify HTTP endpoints, user provisioning/phone-verification orchestration, access-token issuance, and authorization middleware are not implemented. Refresh-token lifecycle primitives now exist, but have not been integrated into an HTTP authentication flow. Do not treat these building blocks as a complete authentication system.

## Integration plan

1. Keep `database/migrations/` as the schema source of truth; do not create divergent tables.
2. Review `apps/api/src/domain/`, API docs, and existing handlers before porting each business operation.
3. Finish OTP request/verify orchestration and refresh-token lifecycle to match the existing API contract.
4. Add domain packages and contract tests for money (integer minor units), pricing, ride state transitions, start-code verification, ledger invariants, and dispatch.
5. Use PostgreSQL transactions and conditional updates for offer acceptance and ride transitions. Never trust client-provided fare or driver identity.
6. Add WebSocket events only after documenting payload compatibility with both Flutter clients.

## Security

Do not commit secrets. Keep production database credentials in the deployment secret store. Configure TLS at the ingress, enforce request body limits and authentication/authorization on business routes, and add rate limiting before public deployment.

## Current status

Incremental scaffold plus OTP and refresh-token service/repository primitives. The complete ride-sharing API has not yet been ported, and this scaffold is not a production replacement for the current TypeScript API. Run `go test ./...` in a Go 1.23+ environment with dependencies available before treating the code as validated.
