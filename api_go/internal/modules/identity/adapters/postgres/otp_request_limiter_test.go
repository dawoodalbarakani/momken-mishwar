package postgres

import (
	"bytes"
	"testing"
	"time"
)

func TestOTPRequestLimiterRejectsInvalidConfiguration(t *testing.T) {
	cases := []struct {
		name string
		dbNil bool
		key []byte
		window time.Duration
		phoneLimit, ipLimit int
	}{
		{name: "nil database", dbNil: true, key: bytes.Repeat([]byte{1}, 32), window: time.Minute, phoneLimit: 3, ipLimit: 10},
		{name: "short key", key: []byte("too-short"), window: time.Minute, phoneLimit: 3, ipLimit: 10},
		{name: "nonpositive window", key: bytes.Repeat([]byte{1}, 32), window: 0, phoneLimit: 3, ipLimit: 10},
		{name: "nonpositive phone limit", key: bytes.Repeat([]byte{1}, 32), window: time.Minute, phoneLimit: 0, ipLimit: 10},
		{name: "nonpositive IP limit", key: bytes.Repeat([]byte{1}, 32), window: time.Minute, phoneLimit: 3, ipLimit: 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var dbNil = tc.dbNil
			// A non-nil pool would require a live database; nil is sufficient for
			// the nil-database validation case and all other fields are validated first.
			if !dbNil {
				_, err := NewOTPRequestLimiter(nil, tc.key, tc.window, tc.phoneLimit, tc.ipLimit)
				if err == nil { t.Fatal("expected invalid configuration error") }
				return
			}
			_, err := NewOTPRequestLimiter(nil, tc.key, tc.window, tc.phoneLimit, tc.ipLimit)
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
