package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

type fakeOTPRepo struct {
	created     domain.OTPChallenge
	requestedIP *string
	verifyHash  string
	createErr   error
	verifyErr   error
}

func (f *fakeOTPRepo) Create(_ context.Context, c domain.OTPChallenge, ip *string) error {
	f.created, f.requestedIP = c, ip
	return f.createErr
}
func (f *fakeOTPRepo) VerifyAndConsume(_ context.Context, phone string, purpose domain.OTPPurpose, hash string, now time.Time) (domain.OTPChallenge, error) {
	f.verifyHash = hash
	return domain.OTPChallenge{PhoneE164: phone, Purpose: purpose, ConsumedAt: &now}, f.verifyErr
}

type fakeDelivery struct {
	phone, code string
	err         error
}

func (f *fakeDelivery) SendCode(_ context.Context, phone, code string) error {
	f.phone, f.code = phone, code
	return f.err
}

type allowLimiter struct{ allowed bool }

func (l allowLimiter) Allow(context.Context, string, string, time.Time) (bool, error) {
	return l.allowed, nil
}

func TestOTPRequestPersistsHashAndDeliversCode(t *testing.T) {
	repo, delivery := &fakeOTPRepo{}, &fakeDelivery{}
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	svc, err := NewOTPService(OTPServiceConfig{
		Repository: repo, Delivery: delivery, Limiter: allowLimiter{allowed: true}, Pepper: []byte("0123456789abcdef0123456789abcdef"),
		TTL: 5 * time.Minute, MaxAttempts: 5, Now: func() time.Time { return now },
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Request(context.Background(), "+967771234567", "127.0.0.1", domain.OTPPurposeLogin); err != nil {
		t.Fatal(err)
	}
	if len(delivery.code) != 6 {
		t.Fatalf("code length = %d", len(delivery.code))
	}
	if repo.created.CodeHash == delivery.code || repo.created.CodeHash == "" {
		t.Fatal("plaintext code was persisted")
	}
	if repo.created.ExpiresAt.Sub(repo.created.CreatedAt) != 5*time.Minute {
		t.Fatal("unexpected challenge TTL")
	}
	if repo.created.PhoneE164 != delivery.phone {
		t.Fatal("delivery phone mismatch")
	}
}

func TestOTPRequestRejectsInvalidPhoneBeforeSideEffects(t *testing.T) {
	repo, delivery := &fakeOTPRepo{}, &fakeDelivery{}
	svc, err := NewOTPService(OTPServiceConfig{Repository: repo, Delivery: delivery, Limiter: allowLimiter{allowed: true}, Pepper: []byte("0123456789abcdef0123456789abcdef"), TTL: time.Minute, MaxAttempts: 3})
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Request(context.Background(), "0771234567", "", domain.OTPPurposeLogin); !errors.Is(err, ErrInvalidPhone) {
		t.Fatalf("error = %v", err)
	}
	if repo.created.ID != "" || delivery.code != "" {
		t.Fatal("invalid phone caused side effects")
	}
}

func TestOTPRequestHonorsLimiter(t *testing.T) {
	repo, delivery := &fakeOTPRepo{}, &fakeDelivery{}
	svc, err := NewOTPService(OTPServiceConfig{Repository: repo, Delivery: delivery, Limiter: allowLimiter{allowed: false}, Pepper: []byte("0123456789abcdef0123456789abcdef"), TTL: time.Minute, MaxAttempts: 3})
	if err != nil {
		t.Fatal(err)
	}
	if err := svc.Request(context.Background(), "+967771234567", "127.0.0.1", domain.OTPPurposeLogin); !errors.Is(err, ErrOTPRequestLimited) {
		t.Fatalf("error = %v", err)
	}
	if repo.created.ID != "" || delivery.code != "" {
		t.Fatal("limited request caused side effects")
	}
}

func TestOTPVerifyHashesCodeBeforeRepository(t *testing.T) {
	repo, delivery := &fakeOTPRepo{}, &fakeDelivery{}
	svc, err := NewOTPService(OTPServiceConfig{Repository: repo, Delivery: delivery, Limiter: allowLimiter{allowed: true}, Pepper: []byte("0123456789abcdef0123456789abcdef"), TTL: time.Minute, MaxAttempts: 3})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Verify(context.Background(), "+967771234567", domain.OTPPurposeLogin, "012345"); err != nil {
		t.Fatal(err)
	}
	if repo.verifyHash == "012345" || len(repo.verifyHash) != 64 {
		t.Fatal("repository received plaintext or malformed hash")
	}
	if constantTimeEqual(repo.verifyHash, "012345") {
		t.Fatal("unexpected hash equality")
	}
}
