package service

import (
	"errors"
	"testing"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

func TestAccessTokenIssueVerifyAndTamper(t *testing.T) {
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	svc, err := NewAccessTokenService(AccessTokenConfig{
		SigningKey: []byte("01234567890123456789012345678901"), Issuer: "api_go",
		Audience: "mishwar-apps", TTL: 15 * time.Minute, Now: func() time.Time { return now },
	})
	if err != nil {
		t.Fatal(err)
	}
	phone := "+967771234567"
	user := domain.User{ID: "user-123", PhoneE164: &phone, Locale: "ar", Status: domain.UserActive,
		Roles: []domain.Role{domain.RoleCustomer}, CreatedAt: now, UpdatedAt: now}
	token, claims, err := svc.Issue(user)
	if err != nil {
		t.Fatal(err)
	}
	if claims.Subject != user.ID || claims.ExpiresAt != now.Add(15*time.Minute).Unix() {
		t.Fatalf("unexpected claims: %+v", claims)
	}
	got, err := svc.Verify(token)
	if err != nil {
		t.Fatal(err)
	}
	if got.Subject != user.ID || len(got.Roles) != 1 || got.Roles[0] != domain.RoleCustomer {
		t.Fatalf("unexpected verified claims: %+v", got)
	}
	tampered := token[:len(token)-1] + "x"
	if _, err := svc.Verify(tampered); !errors.Is(err, ErrAccessTokenInvalid) {
		t.Fatalf("tamper error = %v", err)
	}
}

func TestAccessTokenExpiryAndInactiveUser(t *testing.T) {
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	current := now
	svc, err := NewAccessTokenService(AccessTokenConfig{
		SigningKey: []byte("01234567890123456789012345678901"), Issuer: "api_go",
		Audience: "mishwar-apps", TTL: time.Minute, Now: func() time.Time { return current },
	})
	if err != nil {
		t.Fatal(err)
	}
	phone := "+967771234567"
	user := domain.User{ID: "user-123", PhoneE164: &phone, Locale: "ar", Status: domain.UserActive}
	token, _, err := svc.Issue(user)
	if err != nil {
		t.Fatal(err)
	}
	current = now.Add(time.Minute)
	if _, err := svc.Verify(token); !errors.Is(err, ErrAccessTokenExpired) {
		t.Fatalf("expiry error = %v", err)
	}
	user.Status = domain.UserSuspended
	if _, _, err := svc.Issue(user); !errors.Is(err, domain.ErrUserInactive) {
		t.Fatalf("inactive user error = %v", err)
	}
}
