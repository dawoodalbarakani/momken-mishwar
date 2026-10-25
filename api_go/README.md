# api_go — Mishwar Yemen Go API

This directory starts a Go implementation alongside the existing API. It does not replace or change `apps/api`; port business behavior incrementally and preserve the documented API contract.

## Included

- Go HTTP server with bounded timeouts and graceful shutdown.
- PostgreSQL pool using pgx/v5, with connection validation at startup.
- Liveness and readiness endpoints.
- JSON panic recovery and a versioned API entrypoint.
- Environment-based configuration and a minimal container image.
- Initial identity domain types, OTP challenge lifecycle rules, and a PostgreSQL user repository adapter.

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

The first identity building blocks are present under `internal/modules/identity`:

- `domain`: user roles/status and OTP challenge lifecycle invariants.
- `ports`: user repository interface.
- `adapters/postgres`: lookups against the existing `users` and `user_roles` tables.

OTP delivery, OTP persistence/atomic attempt increments, token issuance/rotation, auth HTTP endpoints, and authorization middleware are not implemented yet. Do not treat these building blocks as a complete authentication system.

## Integration plan

1. Keep `database/migrations/` as the schema source of truth; do not create divergent tables.
2. Review `apps/api/src/domain/`, API docs, and existing handlers before porting each business operation.
3. Add domain packages and contract tests for money (integer minor units), pricing, ride state transitions, start-code verification, ledger invariants, and dispatch.
4. Use PostgreSQL transactions and conditional updates for offer acceptance and ride transitions. Never trust client-provided fare or driver identity.
5. Complete auth/OTP/JWT and refresh-token rotation to match the existing API contract.
6. Add WebSocket events only after documenting payload compatibility with both Flutter clients.

## Security

Do not commit secrets. Keep production database credentials in the deployment secret store. Configure TLS at the ingress, enforce request body limits and authentication/authorization on business routes, and add rate limiting before public deployment.

## Current status

Incremental scaffold plus initial identity domain/repository code. The complete ride-sharing API has not yet been ported, and this scaffold is not a production replacement for the current TypeScript API. Run `go test ./...` in a Go 1.23+ environment with dependencies available before treating the code as validated.
