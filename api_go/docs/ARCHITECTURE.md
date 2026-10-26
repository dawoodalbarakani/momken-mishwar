# api_go Module Architecture

## Architecture decision

Start as a modular monolith: one Go API process, one deployable unit, and explicit business-module boundaries. Avoid microservices until a module has independent scaling, deployment, or operational requirements.

## System shape

Clients (rider_app, driver_app, admin)
-> HTTP REST / WebSocket transport
-> Middleware: request ID, logging, recovery, authentication, rate limits
-> Application use cases
-> Business modules
-> Ports / interfaces
-> PostgreSQL, Redis, maps/geocoding, push/SMS, payment provider

## Recommended Go layout

api_go/
- cmd/api/main.go
- internal/config/
- internal/httpapi/ — router, handlers, middleware, request/response DTOs
- internal/platform/ — postgres, redis, logger, clock, idgen
- internal/modules/
  - identity/ — domain, application, ports, adapters/http, adapters/postgres
  - riders/
  - drivers/
  - rides/
  - dispatch/
  - pricing/
  - locations/
  - payments/
  - notifications/
  - ratings/
  - admin/
- internal/events/ — typed domain events and publisher interfaces
- migrations/
- docs/
- tests/integration/
- Dockerfile
- go.mod

Keep module directories focused; create a subdirectory only when it provides a real boundary. For small modules, domain/application/ports/adapters can initially live in a few files rather than empty folders.

## Module responsibilities

| Module | Owns | Important rules |
|---|---|---|
| identity | Accounts, credentials, sessions, roles | Password hashing, token rotation, authorization |
| riders | Rider profile and preferences | Profile data is separate from authentication |
| drivers | Driver profile, documents, availability | Availability must be consistent with active ride state |
| rides | Ride requests and lifecycle | Enforce valid state transitions in one place |
| dispatch | Candidate selection and assignment | Assignment must be atomic/idempotent; prevent multiple drivers winning one ride |
| pricing | Fare estimates, fare rules, surcharges | Version fare rules; persist the quote used for a ride |
| locations | Driver coordinates and tracking | Validate freshness; do not treat transient location as durable ride state |
| payments | Charges, refunds, wallet ledger | Idempotency keys; ledger entries are append-only |
| notifications | Push, SMS, in-app messages | Send asynchronously and retry safely |
| ratings | Rider/driver ratings and feedback | Validate who may rate whom and when |
| admin | Operations, moderation, configuration | Explicit role/permission checks and audit trail |

## Dependency rules

1. HTTP handlers parse and validate input, call application use cases, and map results to HTTP responses. They contain no business logic or SQL.
2. Application use cases orchestrate domain rules and ports. They must not depend on HTTP or database-driver types.
3. Domain packages must not import transport, PostgreSQL, Redis, or external-provider SDKs.
4. Each module owns its rules and persistence interfaces. Other modules use exported application interfaces or typed events, not another module's tables or repository implementation.
5. Use PostgreSQL transactions for invariants that must be atomic. Redis locks or caches alone must not be the only protection for critical ride assignment.
6. Publish events after commit using a transactional outbox when reliable delivery matters. Consumers must be idempotent.
7. Never expose database models directly as API DTOs.

## Critical ride lifecycle

Suggested initial states:

requested -> matching -> assigned -> driver_arriving -> in_progress -> completed
Any eligible active state may transition to cancelled according to explicit cancellation rules.

Implement transitions as explicit use cases with allowed-transition checks, optimistic concurrency or row locking, and idempotency for client retries. Driver assignment must be guarded by a database constraint/transaction so one ride cannot be assigned to multiple drivers.

## API conventions

- Version routes under /api/v1.
- Return consistent JSON errors with a stable machine-readable code, safe message, and request_id.
- Validate at the transport boundary and re-check domain invariants in the domain/application layer.
- Use context-aware database/provider calls and bounded request timeouts.
- Protect authentication, ride creation, and OTP endpoints with rate limits.
- Keep liveness independent of dependencies; readiness should fail when required dependencies are unavailable.
- Use UTC timestamps in storage and API responses; format local display time in clients.

## Implementation sequence

1. Foundation: configuration, logging, request IDs, error model, PostgreSQL migrations, health/readiness, test harness.
2. Identity: users, password/OTP strategy, access/refresh sessions, authorization.
3. Profiles: riders, drivers, driver onboarding and availability.
4. Ride core: ride requests, fare quote snapshot, lifecycle, cancellation, transaction-safe assignment.
5. Dispatch and locations: nearby-driver search, acceptance timeout, location updates, WebSocket/event delivery.
6. Payments and notifications: idempotent payment workflows, ledger, outbox, retries.
7. Operations: ratings, support, admin audit trail, metrics, tracing and load tests.

## Testing strategy

- Unit tests for domain rules and state transitions.
- Application tests using fake ports.
- PostgreSQL integration tests for migrations, constraints, transaction behavior, and concurrent assignment.
- HTTP tests for validation, authorization, status codes, and error shape.
- Concurrency tests for duplicate ride acceptance and retries.
- End-to-end tests covering rider request -> driver assignment -> trip completion.

## Current scaffold boundary

The initial api_go branch is only the server bootstrap and health/API metadata endpoints. The business modules above are the target architecture, not a claim that those features are already implemented. Migrate incrementally and keep the existing backend available until parity and acceptance tests pass.
