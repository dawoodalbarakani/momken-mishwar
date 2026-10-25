# OTP rate-limit operations

The Go API's PostgreSQL-backed OTP request limiter stores HMAC-SHA256 digests of phone and IP identifiers in `otp_request_limits`. The HMAC key is a deployment secret and must be distinct from the OTP challenge pepper and JWT signing key.

## Migration

Apply `database/migrations/0002_otp_request_limits.sql` before constructing the limiter. Do not enable OTP request routes until the limiter and a real delivery adapter are configured.

## Retention cleanup

Run `OTPRequestLimiter.Cleanup(ctx, cutoff)` from a scheduled maintenance task. Set `cutoff` older than the longest configured rate-limit window so active buckets are not deleted. Record the returned deleted-row count as an operational metric and alert on errors; do not silently ignore failures.

The cleanup method deletes only rows where `window_started_at < cutoff`. It does not require a live OTP request and can be run independently. Choose a schedule appropriate for your traffic and retention requirements.

## Operational cautions

- Keep the limiter key stable across API replicas; rotating it changes the digests and effectively resets existing quotas.
- Store the key in a secret manager, never in source control or application logs.
- Use the trusted direct peer address unless the ingress/proxy trust boundary is explicitly configured; do not accept arbitrary forwarded IP headers.
- Monitor database errors and fail closed on limiter errors before sending an OTP.
- Test quota behavior and concurrent requests against PostgreSQL before production rollout.
