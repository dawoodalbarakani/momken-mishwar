package start_code

import (
	"testing"
	"time"
)

func TestDeriveStartCodeDeterministicAndPadded(t *testing.T) {
	secret := []byte("test-secret")
	nonce, err := NewNonce()
	if err != nil {
		t.Fatal(err)
	}
	code, err := DeriveStartCode(secret, "ride-1", nonce, 4)
	if err != nil {
		t.Fatal(err)
	}
	if len(code) != 4 {
		t.Fatalf("code length = %d, want 4", len(code))
	}
	// Same inputs produce the same code.
	code2, err := DeriveStartCode(secret, "ride-1", nonce, 4)
	if err != nil || code != code2 {
		t.Fatalf("non-deterministic: %q vs %q", code, code2)
	}
}

func TestDeriveStartCodeDifferentNonceDifferentCode(t *testing.T) {
	secret := []byte("test-secret")
	nonce1, _ := NewNonce()
	nonce2, _ := NewNonce()
	c1, _ := DeriveStartCode(secret, "ride-1", nonce1, 4)
	c2, _ := DeriveStartCode(secret, "ride-1", nonce2, 4)
	if c1 == c2 {
		t.Fatal("different nonces should produce different codes")
	}
}

func TestVerifyStartCodeSuccess(t *testing.T) {
	secret := []byte("test-secret")
	nonce, _ := NewNonce()
	code, _ := DeriveStartCode(secret, "ride-1", nonce, 4)
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	expires := now.Add(time.Minute)
	result := VerifyStartCode(VerifyStartCodeInput{
		Secret:       secret,
		RideID:       "ride-1",
		Nonce:        nonce,
		Submitted:    code,
		ExpiresAt:    expires,
		Now:          now,
		AttemptsUsed: 1,
		MaxAttempts:  5,
		Digits:       4,
	})
	if !result.OK {
		t.Fatalf("expected valid code, got reason=%s", result.Reason)
	}
}

func TestVerifyStartCodeWrongCode(t *testing.T) {
	secret := []byte("test-secret")
	nonce, _ := NewNonce()
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	expires := now.Add(time.Minute)
	result := VerifyStartCode(VerifyStartCodeInput{
		Secret:       secret,
		RideID:       "ride-1",
		Nonce:        nonce,
		Submitted:    "0000",
		ExpiresAt:    expires,
		Now:          now,
		AttemptsUsed: 1,
		MaxAttempts:  5,
		Digits:       4,
	})
	if result.OK || result.Reason != ReasonMismatch {
		t.Fatalf("expected mismatch, got ok=%v reason=%s", result.OK, result.Reason)
	}
}

func TestVerifyStartCodeExpired(t *testing.T) {
	secret := []byte("test-secret")
	nonce, _ := NewNonce()
	code, _ := DeriveStartCode(secret, "ride-1", nonce, 4)
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	expires := now.Add(-time.Minute) // already expired
	result := VerifyStartCode(VerifyStartCodeInput{
		Secret:       secret,
		RideID:       "ride-1",
		Nonce:        nonce,
		Submitted:    code,
		ExpiresAt:    expires,
		Now:          now,
		AttemptsUsed: 1,
		MaxAttempts:  5,
		Digits:       4,
	})
	if result.OK || result.Reason != ReasonExpired {
		t.Fatalf("expected expired, got ok=%v reason=%s", result.OK, result.Reason)
	}
}

func TestVerifyStartCodeLocked(t *testing.T) {
	secret := []byte("test-secret")
	nonce, _ := NewNonce()
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	expires := now.Add(time.Minute)
	result := VerifyStartCode(VerifyStartCodeInput{
		Secret:       secret,
		RideID:       "ride-1",
		Nonce:        nonce,
		Submitted:    "0000",
		ExpiresAt:    expires,
		Now:          now,
		AttemptsUsed: 6,
		MaxAttempts:  5,
		Digits:       4,
	})
	if result.OK || result.Reason != ReasonLocked {
		t.Fatalf("expected locked, got ok=%v reason=%s", result.OK, result.Reason)
	}
}

func TestVerifyStartCodeMalformed(t *testing.T) {
	secret := []byte("test-secret")
	nonce, _ := NewNonce()
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	expires := now.Add(time.Minute)
	result := VerifyStartCode(VerifyStartCodeInput{
		Secret:       secret,
		RideID:       "ride-1",
		Nonce:        nonce,
		Submitted:    "abc",
		ExpiresAt:    expires,
		Now:          now,
		AttemptsUsed: 1,
		MaxAttempts:  5,
		Digits:       4,
	})
	if result.OK || result.Reason != ReasonMalformed {
		t.Fatalf("expected malformed, got ok=%v reason=%s", result.OK, result.Reason)
	}
}
