package postgres

import (
	"bytes"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func TestOTPRequestLimiterRejectsInvalidConfiguration(t *testing.T) {
	pool := &pgxpool.Pool{}
	cases := []struct {
		name string
		db *pgxpool.Pool
		key []byte
		window time.Duration
		phoneLimit, ipLimit int
	}{
		{name: "nil database", db: nil, key: bytes.Repeat([]byte{1}, 32), window: time.Minute, phoneLimit: 3, ipLimit: 10},
		{name: "short key", db: pool, key: []byte("too-short"), window: time.Minute, phoneLimit: 3, ipLimit: 10},
		{name: "nonpositive window", db: pool, key: bytes.Repeat([]byte{1}, 32), window: 0, phoneLimit: 3, ipLimit: 10},
		{name: "nonpositive phone limit", db: pool, key: bytes.Repeat([]byte{1}, 32), window: time.Minute, phoneLimit: 0, ipLimit: 10},
		{name: "nonpositive IP limit", db: pool, key: bytes.Repeat([]byte{1}, 32), window: time.Minute, phoneLimit: 3, ipLimit: 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := NewOTPRequestLimiter(tc.db, tc.key, tc.window, tc.phoneLimit, tc.ipLimit)
			if err == nil { t.Fatal("expected invalid configuration error") }
		})
	}
}

func TestOTPRequestLimiterDigestIsScopedAndDoesNotContainInput(t *testing.T) {
	limiter := &OTPRequestLimiter{key: bytes.Repeat([]byte("k"), 32)}
	phone := "+967771234567"
	a := limiter.digest("PHONE", phone)
	b := limiter.digest("PHONE", phone)
	c := limiter.digest("IP", phone)
	if !bytes.Equal(a, b) { t.Fatal("same key and scope should produce a stable digest") }
	if bytes.Equal(a, c) { t.Fatal("different scopes must produce different digests") }
	if bytes.Contains(a, []byte(phone)) { t.Fatal("digest must not contain the raw phone value") }
	if len(a) != 32 { t.Fatalf("digest length = %d, want 32", len(a)) }
}


func TestOTPRequestLimiterCleanupRejectsMissingDatabase(t *testing.T) {
	var limiter *OTPRequestLimiter
	if _, err := limiter.Cleanup(t.Context(), time.Now()); err == nil {
		t.Fatal("expected missing limiter configuration error")
	}
	if _, err := (&OTPRequestLimiter{}).Cleanup(t.Context(), time.Now()); err == nil {
		t.Fatal("expected missing database configuration error")
	}
}
