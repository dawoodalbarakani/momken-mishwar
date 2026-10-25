package ports

import (
	"context"
	"errors"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

var (
	ErrOTPNotFound     = errors.New("OTP challenge not found")
	ErrOTPCodeMismatch = errors.New("OTP code mismatch")
)

// OTPRepository owns the concurrency boundary for one-time codes. Implementations
// must persist failed attempts and consume successful challenges transactionally.
type OTPRepository interface {
	Create(ctx context.Context, challenge domain.OTPChallenge, requestedIP *string) error
	VerifyAndConsume(ctx context.Context, phoneE164 string, purpose domain.OTPPurpose, candidateHash string, now time.Time) (domain.OTPChallenge, error)
}
