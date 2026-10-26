package service

import (
	"context"
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

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/ports"
)

var (
	ErrInvalidPhone      = errors.New("phone must be E.164 formatted")
	ErrOTPDelivery       = errors.New("OTP delivery failed")
	ErrOTPConfig         = errors.New("OTP service is not configured")
	ErrOTPRequestLimited = errors.New("OTP request rate limited")
)

var e164Pattern = regexp.MustCompile(`^\+[1-9][0-9]{7,14}$`)

type OTPDelivery interface {
	SendCode(ctx context.Context, phoneE164, code string) error
}

type OTPRequestLimiter interface {
	Allow(ctx context.Context, phoneE164, clientIP string, now time.Time) (bool, error)
}

type OTPService struct {
	repository  ports.OTPRepository
	delivery    OTPDelivery
	limiter     OTPRequestLimiter
	pepper      []byte
	ttl         time.Duration
	maxAttempts int
	now         func() time.Time
}

type OTPServiceConfig struct {
	Repository  ports.OTPRepository
	Delivery    OTPDelivery
	Limiter     OTPRequestLimiter
	Pepper      []byte
	TTL         time.Duration
	MaxAttempts int
	Now         func() time.Time
}

func NewOTPService(cfg OTPServiceConfig) (*OTPService, error) {
	if cfg.Repository == nil || cfg.Delivery == nil || cfg.Limiter == nil || len(cfg.Pepper) < 32 ||
		cfg.TTL <= 0 || cfg.MaxAttempts <= 0 {
		return nil, ErrOTPConfig
	}
	if cfg.Now == nil {
		cfg.Now = time.Now
	}
	return &OTPService{
		repository: cfg.Repository, delivery: cfg.Delivery, limiter: cfg.Limiter,
		pepper: append([]byte(nil), cfg.Pepper...), ttl: cfg.TTL,
		maxAttempts: cfg.MaxAttempts, now: cfg.Now,
	}, nil
}

// Request creates a short-lived challenge. The code is never returned to the caller.
// A production deployment must provide a shared, distributed limiter and delivery adapter.
func (s *OTPService) Request(ctx context.Context, phoneE164, clientIP string, purpose domain.OTPPurpose) error {
	if !e164Pattern.MatchString(phoneE164) {
		return ErrInvalidPhone
	}
	if purpose != domain.OTPPurposeLogin && purpose != domain.OTPPurposeVerifyPhone {
		return domain.ErrInvalidOTPChallenge
	}
	now := s.now().UTC()
	allowed, err := s.limiter.Allow(ctx, phoneE164, clientIP, now)
	if err != nil {
		return fmt.Errorf("check OTP request limit: %w", err)
	}
	if !allowed {
		return ErrOTPRequestLimited
	}

	code, err := generateNumericCode(6)
	if err != nil {
		return fmt.Errorf("generate OTP: %w", err)
	}
	id, err := newUUID()
	if err != nil {
		return fmt.Errorf("generate OTP challenge ID: %w", err)
	}
	challenge := domain.OTPChallenge{
		ID: id, PhoneE164: phoneE164, Purpose: purpose,
		CodeHash: s.hash(phoneE164, purpose, code),
		Attempts: 0, MaxAttempts: s.maxAttempts,
		CreatedAt: now, ExpiresAt: now.Add(s.ttl),
	}
	var ip *string
	if clientIP != "" {
		ip = &clientIP
	}
	if err := s.repository.Create(ctx, challenge, ip); err != nil {
		return fmt.Errorf("persist OTP challenge: %w", err)
	}
	if err := s.delivery.SendCode(ctx, phoneE164, code); err != nil {
		// Do not expose provider details or the OTP. The persisted challenge expires naturally.
		return fmt.Errorf("%w", ErrOTPDelivery)
	}
	return nil
}

// Verify accepts a code only as input and immediately converts it to a keyed hash.
// The repository serializes attempts and single-use consumption in PostgreSQL.
func (s *OTPService) Verify(ctx context.Context, phoneE164 string, purpose domain.OTPPurpose, code string) (domain.OTPChallenge, error) {
	if !e164Pattern.MatchString(phoneE164) || len(code) != 6 {
		return domain.OTPChallenge{}, domain.ErrInvalidOTPChallenge
	}
	for _, r := range code {
		if r < '0' || r > '9' {
			return domain.OTPChallenge{}, domain.ErrInvalidOTPChallenge
		}
	}
	candidate := s.hash(phoneE164, purpose, code)
	return s.repository.VerifyAndConsume(ctx, phoneE164, purpose, candidate, s.now().UTC())
}

func (s *OTPService) hash(phone string, purpose domain.OTPPurpose, code string) string {
	mac := hmac.New(sha256.New, s.pepper)
	_, _ = fmt.Fprintf(mac, "%s\x00%s\x00%s", phone, purpose, code)
	return hex.EncodeToString(mac.Sum(nil))
}

func generateNumericCode(digits int) (string, error) {
	max := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(digits)), nil)
	n, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%0*d", digits, n.Int64()), nil
}

func newUUID() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	encoded := hex.EncodeToString(b[:])
	return fmt.Sprintf("%s-%s-%s-%s-%s", encoded[:8], encoded[8:12], encoded[12:16], encoded[16:20], encoded[20:]), nil
}

// constantTimeEqual is intentionally small and is used by tests to guard hash behavior.
func constantTimeEqual(a, b string) bool {
	return subtle.ConstantTimeCompare([]byte(a), []byte(b)) == 1
}
