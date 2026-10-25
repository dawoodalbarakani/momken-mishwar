package domain

import (
	"errors"
	"time"
)

type OTPPurpose string

const (
	OTPPurposeLogin       OTPPurpose = "LOGIN"
	OTPPurposeVerifyPhone OTPPurpose = "VERIFY_PHONE"
)

var (
	ErrInvalidOTPChallenge = errors.New("invalid OTP challenge")
	ErrOTPExpired          = errors.New("OTP challenge expired")
	ErrOTPConsumed         = errors.New("OTP challenge already consumed")
	ErrOTPAttemptsExceeded = errors.New("OTP challenge attempts exceeded")
)

type OTPChallenge struct {
	ID          string
	PhoneE164   string
	Purpose     OTPPurpose
	CodeHash    string
	Attempts    int
	MaxAttempts int
	ExpiresAt   time.Time
	ConsumedAt  *time.Time
	CreatedAt   time.Time
}

func (c OTPChallenge) Validate() error {
	if c.ID == "" || c.PhoneE164 == "" || c.CodeHash == "" {
		return ErrInvalidOTPChallenge
	}
	if c.Purpose != OTPPurposeLogin && c.Purpose != OTPPurposeVerifyPhone {
		return ErrInvalidOTPChallenge
	}
	if c.Attempts < 0 || c.MaxAttempts <= 0 || c.Attempts > c.MaxAttempts {
		return ErrInvalidOTPChallenge
	}
	if !c.ExpiresAt.After(c.CreatedAt) {
		return ErrInvalidOTPChallenge
	}
	return nil
}

// CanAttempt is a pure domain check. The repository must increment attempts
// atomically in PostgreSQL before accepting or rejecting a submitted code.
func (c OTPChallenge) CanAttempt(now time.Time) error {
	if err := c.Validate(); err != nil {
		return err
	}
	if c.ConsumedAt != nil {
		return ErrOTPConsumed
	}
	if !now.Before(c.ExpiresAt) {
		return ErrOTPExpired
	}
	if c.Attempts >= c.MaxAttempts {
		return ErrOTPAttemptsExceeded
	}
	return nil
}
