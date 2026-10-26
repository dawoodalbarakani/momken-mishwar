package start_code

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"regexp"
	"time"
)

const (
	// StartCodeDigits is the number of decimal digits in the derived code.
	StartCodeDigits = 4
)

var (
	ErrStartCodeMalformed = errors.New("start code is malformed")
	ErrStartCodeExpired   = errors.New("start code expired")
	ErrStartCodeLocked    = errors.New("start code locked: too many attempts")
	ErrStartCodeMismatch  = errors.New("start code mismatch")
)

var digitPattern = regexp.MustCompile(`^[0-9]+$`)

// NewNonce returns a cryptographically random 16-byte nonce for a ride's start code.
func NewNonce() ([]byte, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	return b, nil
}

// DeriveStartCode computes the start code as HMAC-SHA256(secret, rideId || \x00 || nonce)
// truncated to the requested number of decimal digits. The code is derived, not stored.
func DeriveStartCode(secret []byte, rideID string, nonce []byte, digits int) (string, error) {
	if digits < 4 || digits > 8 {
		return "", fmt.Errorf("digits must be between 4 and 8, got %d", digits)
	}
	mac := hmac.New(sha256.New, secret)
	_, _ = mac.Write([]byte(rideID))
	_, _ = mac.Write([]byte{0})
	_, _ = mac.Write(nonce)
	digest := mac.Sum(nil)
	n := uint32(digest[0])<<24 | uint32(digest[1])<<16 | uint32(digest[2])<<8 | uint32(digest[3])
	mod := big.NewInt(10)
	mod.Exp(mod, big.NewInt(int64(digits)), nil)
	bigN := big.NewInt(int64(n))
	bigN.Mod(bigN, mod)
	code := fmt.Sprintf("%0*d", digits, bigN.Int64())
	return code, nil
}

// StartCodeResult is the outcome of verifying a submitted start code.
type StartCodeResult struct {
	OK     bool
	Reason string
}

const (
	ReasonMalformed = "MALFORMED"
	ReasonExpired   = "EXPIRED"
	ReasonLocked    = "LOCKED"
	ReasonMismatch  = "MISMATCH"
)

// VerifyStartCodeInput contains all inputs needed to verify a start code.
// AttemptsUsed must include the current attempt (already incremented atomically
// in SQL before calling this function).
type VerifyStartCodeInput struct {
	Secret       []byte
	RideID       string
	Nonce        []byte
	Submitted    string
	ExpiresAt    time.Time
	Now          time.Time
	AttemptsUsed int
	MaxAttempts  int
	Digits       int
}

// VerifyStartCode validates a submitted start code in constant time.
// It does not increment the attempt counter; the caller must do that in SQL.
func VerifyStartCode(input VerifyStartCodeInput) StartCodeResult {
	digits := input.Digits
	if digits < 4 || digits > 8 {
		digits = StartCodeDigits
	}
	if input.AttemptsUsed > input.MaxAttempts {
		return StartCodeResult{OK: false, Reason: ReasonLocked}
	}
	if !input.Now.Before(input.ExpiresAt) {
		return StartCodeResult{OK: false, Reason: ReasonExpired}
	}
	if !digitPattern.MatchString(input.Submitted) || len(input.Submitted) != digits {
		return StartCodeResult{OK: false, Reason: ReasonMalformed}
	}
	expected, err := DeriveStartCode(input.Secret, input.RideID, input.Nonce, digits)
	if err != nil {
		return StartCodeResult{OK: false, Reason: ReasonMismatch}
	}
	expectedBuf := []byte(expected)
	givenBuf := []byte(input.Submitted)
	equal := len(expectedBuf) == len(givenBuf) && subtle.ConstantTimeCompare(expectedBuf, givenBuf) == 1
	if equal {
		return StartCodeResult{OK: true, Reason: ""}
	}
	return StartCodeResult{OK: false, Reason: ReasonMismatch}
}

// HashSecret returns the SHA-256 digest of a start code secret, suitable for
// comparison or storage of the secret itself (not the code).
func HashSecret(secret []byte) string {
	sum := sha256.Sum256(secret)
	return hex.EncodeToString(sum[:])
}

var _ = hmac.New // kept for symmetry; DeriveStartCode uses hmac directly
