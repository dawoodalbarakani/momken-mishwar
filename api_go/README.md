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
- Access-token service that issues and verifies short-lived HS256 JWTs with issuer/audience checks, expiration, and user-role claims.
- Reusable bearer-token middleware that adds verified claims to request context and rejects missing or invalid tokens.

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
- `ports`: repository interfaces for users, OTP challenges, and refresh tokens.
- `adapters/postgres`: user/role lookups, OTP persistence and row-locked verification, refresh-token rotation/revocation, and a shared PostgreSQL fixed-window OTP request limiter.
- `service`: cryptographically random six-digit OTP generation, keyed HMAC-SHA256 challenge storage/verification, access-token issuance/verification, session login/refresh, and refresh-token family revocation.
- `internal/httpapi/auth_handlers.go`: OTP request, OTP login, refresh, and logout handlers with strict JSON decoding and bounded request bodies.

The shared OTP limiter is implemented in `adapters/postgres/otp_request_limiter.go`; it enforces separate phone and IP quotas transactionally across API instances. It stores HMAC digests of scope identifiers rather than raw phone/IP values. Apply `database/migrations/0002_otp_request_limits.sql` before using it. Supply a dedicated random limiter key of at least 32 bytes, distinct from the OTP challenge pepper and JWT signing key. The rate-limit table requires periodic retention cleanup; schedule deletion of rows whose `window_started_at` is older than your retention window.

The HTTP handlers and service building blocks are not yet wired into `cmd/api/main.go`. Production activation still requires a real SMS/voice delivery adapter, secrets from the deployment secret store, limiter configuration, and integration/contract tests. Do not expose OTP endpoints publicly until the real delivery provider and shared limiter are configured. Account provisioning and phone-verification workflows also require explicit product policy. Do not treat this scaffold as a production replacement for the existing TypeScript API.

## Integration plan

1. Keep `database/migrations/` as the schema source of truth; do not create divergent tables.
2. Review `apps/api/src/domain/`, API docs, and existing handlers before porting each business operation.
3. Finish OTP request/verify orchestration and refresh-token lifecycle to match the existing API contract.
4. Add domain packages and contract tests for money (integer minor units), pricing, ride state transitions, start-code verification, ledger invariants, and dispatch.
5. Use PostgreSQL transactions and conditional updates for offer acceptance and ride transitions. Never trust client-provided fare or driver identity.
6. Add WebSocket events only after documenting payload compatibility with both Flutter clients.

## Security

Do not commit secrets. Keep production database credentials in the deployment secret store. Configure TLS at the ingress, enforce request body limits and authentication/authorization on business routes, and add rate limiting before public deployment.


### OTP-backed session orchestration

`internal/modules/identity/service/session_service.go` coordinates LOGIN OTP consumption, account lookup, active/verified-phone checks, access-token issuance, and refresh-token creation. It intentionally does not auto-provision accounts. This service is not exposed through HTTP routes yet; configure real OTP delivery and a shared limiter before public deployment. See `docs/AUTH_SESSION_FLOW.md`.

## Current status

Incremental scaffold plus OTP, refresh-token, and access-token service/repository primitives. The complete ride-sharing API has not yet been ported, and this scaffold is not a production replacement for the current TypeScript API. Run `go test ./...` in a Go 1.23+ environment with dependencies available before treating the code as validated.
