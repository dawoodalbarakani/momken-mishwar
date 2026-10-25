# Authentication integration roadmap

The current identity package contains reusable OTP, access-token, and refresh-token primitives. They are not yet a complete public authentication API.

## Required sequence

1. Configure a real OTP delivery provider and a shared distributed request limiter. Never log or return OTP codes.
2. Add an identity session service that verifies the LOGIN challenge, loads the account by E.164 phone number, and issues access and refresh tokens only for eligible accounts.
3. Define an explicit account-provisioning policy before creating new users. Do not silently grant privileged roles; default public registrations to CUSTOMER only after product policy is confirmed.
4. Add request/verify, refresh, and logout HTTP handlers with strict request-size limits, generic public errors, and rate limits.
5. Add role middleware around protected routes, after validating claims through the access-token middleware.
6. Add integration tests against PostgreSQL for OTP single-use behavior, refresh rotation/reuse revocation, expiry, and role denial.
7. Enable Go formatting, test, and vet checks in CI and verify the run before merging.

## Production gates

- Do not enable OTP endpoints with a fake delivery provider or in-memory-only limiter.
- Do not return access tokens until OTP verification and account eligibility both succeed.
- Store only OTP hashes and refresh-token hashes; keep signing keys and OTP pepper in a secret manager.
- Keep the existing TypeScript API as the compatibility reference until route and payload parity is tested.
