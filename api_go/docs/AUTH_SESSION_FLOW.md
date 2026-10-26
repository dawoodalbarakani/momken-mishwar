# OTP session service

The identity service now exposes an OTP-backed login orchestration primitive.

## Login sequence

1. Verify and consume the single-use LOGIN OTP challenge.
2. Look up the account by its E.164 phone number.
3. Validate the user domain model and require an active account.
4. Require the phone number to match the account and already be marked verified.
5. Issue a short-lived access token and create an opaque refresh token whose hash is persisted.

The service deliberately does not auto-create users or assign roles. Public registration needs an explicit product policy and a transactionally safe user-provisioning implementation.

## Not yet wired

This is a service-layer primitive, not a public endpoint. HTTP handlers, refresh/logout orchestration, production SMS delivery, distributed rate limiting, runtime configuration for secrets, and end-to-end integration tests remain outstanding. Do not expose login until these dependencies are configured and verified.
