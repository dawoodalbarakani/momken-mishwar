package postgres

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"errors"
	"fmt"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrOTPRequestLimiterConfig = errors.New("OTP request limiter is not configured")

// OTPRequestLimiter stores fixed-window counters in PostgreSQL so limits apply
// across API instances. The HMAC key must be a separate deployment secret.
type OTPRequestLimiter struct {
	db *pgxpool.Pool
	key []byte
	window time.Duration
	phoneLimit int
	ipLimit int
}

func NewOTPRequestLimiter(db *pgxpool.Pool, key []byte, window time.Duration, phoneLimit, ipLimit int) (*OTPRequestLimiter, error) {
	if db == nil || len(key) < 32 || window <= 0 || phoneLimit <= 0 || ipLimit <= 0 {
		return nil, ErrOTPRequestLimiterConfig
	}
	return &OTPRequestLimiter{db: db, key: append([]byte(nil), key...), window: window, phoneLimit: phoneLimit, ipLimit: ipLimit}, nil
}

// Allow atomically reserves one request in both the phone and IP buckets.
// A denied request rolls back both reservations so a blocked IP does not consume
// a phone's quota. Empty client IP skips the IP bucket, never the phone bucket.
func (l *OTPRequestLimiter) Allow(ctx context.Context, phoneE164, clientIP string, now time.Time) (bool, error) {
	if l == nil || l.db == nil || len(l.key) < 32 || l.window <= 0 || l.phoneLimit <= 0 || l.ipLimit <= 0 {
		return false, ErrOTPRequestLimiterConfig
	}
	if phoneE164 == "" {
		return false, errors.New("phone is required for OTP rate limiting")
	}
	windowStart := time.Unix(0, (now.UTC().UnixNano()/int64(l.window))*int64(l.window)).UTC()
	type bucket struct { scope string; digest []byte; limit int }
	buckets := []bucket{{scope: "PHONE", digest: l.digest("PHONE", phoneE164), limit: l.phoneLimit}}
	if clientIP != "" {
		buckets = append(buckets, bucket{scope: "IP", digest: l.digest("IP", clientIP), limit: l.ipLimit})
	}
	sort.Slice(buckets, func(i, j int) bool {
		if buckets[i].scope != buckets[j].scope { return buckets[i].scope < buckets[j].scope }
		return string(buckets[i].digest) < string(buckets[j].digest)
	})

	tx, err := l.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil { return false, fmt.Errorf("begin OTP rate limit transaction: %w", err) }
	defer func() { _ = tx.Rollback(ctx) }()
	for _, b := range buckets {
		var count int
		err := tx.QueryRow(ctx, `
			INSERT INTO otp_request_limits (scope_type, scope_hash, window_started_at, request_count, updated_at)
			VALUES ($1, $2, $3, 1, $4)
			ON CONFLICT (scope_type, scope_hash) DO UPDATE SET
				window_started_at = EXCLUDED.window_started_at,
				request_count = CASE
					WHEN otp_request_limits.window_started_at = EXCLUDED.window_started_at
					THEN otp_request_limits.request_count + 1 ELSE 1 END,
				updated_at = EXCLUDED.updated_at
			WHERE otp_request_limits.window_started_at <> EXCLUDED.window_started_at
			   OR otp_request_limits.request_count < $5
			RETURNING request_count`, b.scope, b.digest, windowStart, now.UTC(), b.limit).Scan(&count)
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		if err != nil { return false, fmt.Errorf("reserve OTP %s rate limit: %w", b.scope, err) }
	}
	if err := tx.Commit(ctx); err != nil { return false, fmt.Errorf("commit OTP rate limit transaction: %w", err) }
	return true, nil
}

func (l *OTPRequestLimiter) digest(scope, value string) []byte {
	mac := hmac.New(sha256.New, l.key)
	_, _ = mac.Write([]byte(scope))
	_, _ = mac.Write([]byte{0})
	_, _ = mac.Write([]byte(value))
	return mac.Sum(nil)
}


// Cleanup removes expired rate-limit buckets. Call it from a scheduled maintenance
// job with a cutoff older than the maximum active window.
func (l *OTPRequestLimiter) Cleanup(ctx context.Context, before time.Time) (int64, error) {
	if l == nil || l.db == nil {
		return 0, ErrOTPRequestLimiterConfig
	}
	tag, err := l.db.Exec(ctx, `DELETE FROM otp_request_limits WHERE window_started_at < $1`, before.UTC())
	if err != nil {
		return 0, fmt.Errorf("clean up expired OTP rate limit buckets: %w", err)
	}
	return tag.RowsAffected(), nil
}
