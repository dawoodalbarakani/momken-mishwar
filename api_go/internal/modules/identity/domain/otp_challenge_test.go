package domain

import (
	"errors"
	"testing"
	"time"
)

func validChallenge() OTPChallenge {
	now := time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)
	return OTPChallenge{
		ID: "challenge-1",
		PhoneE164: "+967771234567",
		Purpose: OTPPurposeLogin,
		CodeHash: "not-a-plaintext-code",
		Attempts: 0,
		MaxAttempts: 3,
		CreatedAt: now,
		ExpiresAt: now.Add(5 * time.Minute),
	}
}

func TestOTPChallengeCanAttempt(t *testing.T) {
	c := validChallenge()
	now := c.CreatedAt.Add(time.Minute)
	if err := c.CanAttempt(now); err != nil {
		t.Fatalf("CanAttempt() unexpected error: %v", err)
	}
}

func TestOTPChallengeRejectsExpiredConsumedAndExhausted(t *testing.T) {
	c := validChallenge()
	now := c.CreatedAt.Add(5 * time.Minute)
	if err := c.CanAttempt(now); !errors.Is(err, ErrOTPExpired) {
		t.Errorf("expired challenge error = %v, want ErrOTPExpired", err)
	}

	c = validChallenge()
	consumed := c.CreatedAt.Add(time.Minute)
	c.ConsumedAt = &consumed
	if err := c.CanAttempt(c.CreatedAt); !errors.Is(err, ErrOTPConsumed) {
		t.Errorf("consumed challenge error = %v, want ErrOTPConsumed", err)
	}

	c = validChallenge()
	c.Attempts = c.MaxAttempts
	if err := c.CanAttempt(c.CreatedAt); !errors.Is(err, ErrOTPAttemptsExceeded) {
		t.Errorf("exhausted challenge error = %v, want ErrOTPAttemptsExceeded", err)
	}
}
