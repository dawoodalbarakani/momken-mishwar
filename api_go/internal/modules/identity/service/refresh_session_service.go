package service

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/ports"
)

var ErrRefreshSessionConfig = errors.New("refresh session service is not configured")

type RefreshSessionResult struct {
	AccessToken string
	AccessTokenExpiresAt int64
	RefreshToken string
	RefreshTokenExpiresAt int64
	User domain.User
}

type RefreshSessionService struct {
	users ports.UserRepository
	refresh *RefreshTokenService
	access *AccessTokenService
}

type RefreshSessionServiceConfig struct {
	Users ports.UserRepository
	RefreshTokens *RefreshTokenService
	AccessTokens *AccessTokenService
}

func NewRefreshSessionService(cfg RefreshSessionServiceConfig) (*RefreshSessionService, error) {
	if cfg.Users == nil || cfg.RefreshTokens == nil || cfg.AccessTokens == nil {
		return nil, ErrRefreshSessionConfig
	}
	return &RefreshSessionService{users: cfg.Users, refresh: cfg.RefreshTokens, access: cfg.AccessTokens}, nil
}

// Refresh rotates the opaque credential before reloading the account and issuing
// a new access token. If the account can no longer authenticate, its token family
// is revoked so the rotated credential cannot be used again.
func (s *RefreshSessionService) Refresh(ctx context.Context, rawToken string, deviceID *string) (RefreshSessionResult, error) {
	rawToken = strings.TrimSpace(rawToken)
	if rawToken == "" {
		return RefreshSessionResult{}, domain.ErrRefreshTokenInvalid
	}
	next, userID, err := s.refresh.Rotate(ctx, rawToken, deviceID)
	if err != nil {
		return RefreshSessionResult{}, err
	}
	user, err := s.users.FindByID(ctx, userID)
	if err != nil {
		_ = s.refresh.RevokeFamily(ctx, next.FamilyID, "ACCOUNT_LOOKUP_FAILED")
		if errors.Is(err, ports.ErrUserNotFound) {
			return RefreshSessionResult{}, domain.ErrRefreshTokenInvalid
		}
		return RefreshSessionResult{}, fmt.Errorf("reload account after refresh: %w", err)
	}
	if err := user.Validate(); err != nil || !user.CanAuthenticate() {
		_ = s.refresh.RevokeFamily(ctx, next.FamilyID, "ACCOUNT_INACTIVE")
		return RefreshSessionResult{}, domain.ErrUserInactive
	}
	accessToken, claims, err := s.access.Issue(user)
	if err != nil {
		_ = s.refresh.RevokeFamily(ctx, next.FamilyID, "ACCESS_TOKEN_ISSUE_FAILED")
		return RefreshSessionResult{}, fmt.Errorf("issue access token after refresh: %w", err)
	}
	return RefreshSessionResult{
		AccessToken: accessToken, AccessTokenExpiresAt: claims.ExpiresAt,
		RefreshToken: next.RefreshToken, RefreshTokenExpiresAt: next.ExpiresAt.Unix(), User: user,
	}, nil
}
