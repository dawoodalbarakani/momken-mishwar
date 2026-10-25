package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/ports"
)

var (
	ErrSessionConfig = errors.New("identity session service is not configured")
	ErrPhoneNotVerified = errors.New("phone number is not verified")
)

// LoginSession contains credentials returned only after a valid, single-use OTP
// and an active account with a verified phone number have both been confirmed.
type LoginSession struct {
	AccessToken string
	AccessTokenExpiresAt int64
	RefreshToken string
	RefreshTokenExpiresAt int64
	RefreshFamilyID string
	User domain.User
}

type OTPVerifier interface {
	Verify(ctx context.Context, phoneE164 string, purpose domain.OTPPurpose, code string) (domain.OTPChallenge, error)
}

type SessionService struct {
	otp OTPVerifier
	users ports.UserRepository
	refresh *RefreshTokenService
	access *AccessTokenService
}

type SessionServiceConfig struct {
	OTP OTPVerifier
	Users ports.UserRepository
	RefreshTokens *RefreshTokenService
	AccessTokens *AccessTokenService
}

func NewSessionService(cfg SessionServiceConfig) (*SessionService, error) {
	if cfg.OTP == nil || cfg.Users == nil || cfg.RefreshTokens == nil || cfg.AccessTokens == nil {
		return nil, ErrSessionConfig
	}
	return &SessionService{otp: cfg.OTP, users: cfg.Users, refresh: cfg.RefreshTokens, access: cfg.AccessTokens}, nil
}

// Login verifies and consumes the LOGIN challenge before looking up the account.
// It deliberately does not auto-provision users or assign roles; registration
// must follow an explicit product policy and a separate transactional flow.
func (s *SessionService) Login(ctx context.Context, phoneE164, code string, deviceID *string) (LoginSession, error) {
	if _, err := s.otp.Verify(ctx, phoneE164, domain.OTPPurposeLogin, code); err != nil {
		return LoginSession{}, err
	}
	user, err := s.users.FindByPhone(ctx, phoneE164)
	if err != nil {
		if errors.Is(err, ports.ErrUserNotFound) {
			return LoginSession{}, ports.ErrUserNotFound
		}
		return LoginSession{}, fmt.Errorf("load account after OTP verification: %w", err)
	}
	if err := user.Validate(); err != nil {
		return LoginSession{}, fmt.Errorf("validate account: %w", err)
	}
	if !user.CanAuthenticate() {
		return LoginSession{}, domain.ErrUserInactive
	}
	if user.PhoneE164 == nil || *user.PhoneE164 != phoneE164 || user.PhoneVerifiedAt == nil {
		return LoginSession{}, ErrPhoneNotVerified
	}
	accessToken, accessClaims, err := s.access.Issue(user)
	if err != nil {
		return LoginSession{}, fmt.Errorf("issue access token: %w", err)
	}
	refresh, err := s.refresh.Create(ctx, user.ID, deviceID)
	if err != nil {
		return LoginSession{}, fmt.Errorf("create refresh session: %w", err)
	}
	return LoginSession{
		AccessToken: accessToken, AccessTokenExpiresAt: accessClaims.ExpiresAt,
		RefreshToken: refresh.RefreshToken, RefreshTokenExpiresAt: refresh.ExpiresAt.Unix(),
		RefreshFamilyID: refresh.FamilyID, User: user,
	}, nil
}
