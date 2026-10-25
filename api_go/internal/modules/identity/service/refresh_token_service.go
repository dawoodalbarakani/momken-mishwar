package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/ports"
)

var ErrRefreshServiceConfig = errors.New("refresh token service is not configured")

type RefreshTokenService struct {
	repository ports.RefreshTokenRepository
	ttl time.Duration
	now func() time.Time
}

type RefreshTokenServiceConfig struct {
	Repository ports.RefreshTokenRepository
	TTL time.Duration
	Now func() time.Time
}

type RefreshSession struct {
	RefreshToken string
	FamilyID string
	ExpiresAt time.Time
}

func NewRefreshTokenService(cfg RefreshTokenServiceConfig) (*RefreshTokenService, error) {
	if cfg.Repository == nil || cfg.TTL <= 0 {
		return nil, ErrRefreshServiceConfig
	}
	if cfg.Now == nil { cfg.Now = time.Now }
	return &RefreshTokenService{repository: cfg.Repository, ttl: cfg.TTL, now: cfg.Now}, nil
}

// Create issues an opaque, high-entropy refresh credential. Only its SHA-256
// digest is persisted; the raw token is returned once to the trusted caller.
func (s *RefreshTokenService) Create(ctx context.Context, userID string, deviceID *string) (RefreshSession, error) {
	if userID == "" { return RefreshSession{}, errors.New("user ID is required") }
	now := s.now().UTC()
	raw, err := newRefreshSecret()
	if err != nil { return RefreshSession{}, fmt.Errorf("generate refresh secret: %w", err) }
	id, err := newUUID()
	if err != nil { return RefreshSession{}, fmt.Errorf("generate refresh token ID: %w", err) }
	familyID, err := newUUID()
	if err != nil { return RefreshSession{}, fmt.Errorf("generate refresh family ID: %w", err) }
	token := domain.RefreshToken{
		ID: id, UserID: userID, FamilyID: familyID, TokenHash: hashRefreshSecret(raw),
		DeviceID: deviceID, CreatedAt: now, ExpiresAt: now.Add(s.ttl),
	}
	if err := s.repository.Create(ctx, token); err != nil {
		return RefreshSession{}, fmt.Errorf("persist refresh token: %w", err)
	}
	return RefreshSession{RefreshToken: raw, FamilyID: familyID, ExpiresAt: token.ExpiresAt}, nil
}

// Rotate invalidates the submitted token and creates its successor atomically.
// Reuse of an already rotated token revokes the entire token family in storage.
func (s *RefreshTokenService) Rotate(ctx context.Context, rawToken string, deviceID *string) (RefreshSession, string, error) {
	if rawToken == "" { return RefreshSession{}, "", domain.ErrRefreshTokenInvalid }
	now := s.now().UTC()
	raw, err := newRefreshSecret()
	if err != nil { return RefreshSession{}, "", fmt.Errorf("generate refresh secret: %w", err) }
	id, err := newUUID()
	if err != nil { return RefreshSession{}, "", fmt.Errorf("generate refresh token ID: %w", err) }
	replacement := domain.RefreshToken{
		ID: id, TokenHash: hashRefreshSecret(raw), DeviceID: deviceID,
		CreatedAt: now, ExpiresAt: now.Add(s.ttl),
	}
	userID, familyID, err := s.repository.Rotate(ctx, hashRefreshSecret(rawToken), replacement, now)
	if err != nil { return RefreshSession{}, "", err }
	return RefreshSession{RefreshToken: raw, FamilyID: familyID, ExpiresAt: replacement.ExpiresAt}, userID, nil
}

func newRefreshSecret() (string, error) {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil { return "", err }
	return base64.RawURLEncoding.EncodeToString(b[:]), nil
}

func hashRefreshSecret(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

// RevokeFamily invalidates every refresh credential in a family, including
// rotated credentials, using the repository's atomic family update.
func (s *RefreshTokenService) RevokeFamily(ctx context.Context, familyID, reason string) error {
	if familyID == "" || reason == "" {
		return errors.New("family ID and revocation reason are required")
	}
	return s.repository.RevokeFamily(ctx, familyID, reason, s.now().UTC())
}

// Revoke invalidates the complete family identified by a presented refresh token.
// Only the token digest is passed to the repository.
func (s *RefreshTokenService) Revoke(ctx context.Context, rawToken, reason string) error {
	if rawToken == "" { return domain.ErrRefreshTokenInvalid }
	if reason == "" { reason = "LOGOUT" }
	return s.repository.RevokeByHash(ctx, hashRefreshSecret(rawToken), reason, s.now().UTC())
}
