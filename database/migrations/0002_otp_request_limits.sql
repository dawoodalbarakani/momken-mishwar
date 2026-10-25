-- PostgreSQL-backed, cross-instance OTP request rate limits.
-- Scope identifiers are keyed HMAC digests; raw phone numbers and IPs are not stored.
BEGIN;

CREATE TABLE otp_request_limits (
  scope_type text NOT NULL CHECK (scope_type IN ('PHONE', 'IP')),
  scope_hash bytea NOT NULL CHECK (octet_length(scope_hash) = 32),
  window_started_at timestamptz NOT NULL,
  request_count integer NOT NULL CHECK (request_count > 0),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (scope_type, scope_hash)
);
CREATE INDEX otp_request_limits_window_idx ON otp_request_limits (window_started_at);

INSERT INTO schema_migrations (version, description)
VALUES ('0002', 'OTP request rate limit buckets');

COMMIT;
