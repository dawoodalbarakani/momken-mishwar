package service

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

var (
	ErrAccessTokenConfig = errors.New("access token service is not configured")
	ErrAccessTokenInvalid = errors.New("access token is invalid")
	ErrAccessTokenExpired = errors.New("access token is expired")
)

type AccessTokenClaims struct {
	Subject string `json:"sub"`
	Issuer string `json:"iss"`
	Audience string `json:"aud"`
	IssuedAt int64 `json:"iat"`
	ExpiresAt int64 `json:"exp"`
	Roles []domain.Role `json:"roles"`
}

type AccessTokenService struct {
	key []byte
	issuer string
	audience string
	ttl time.Duration
	now func() time.Time
}

type AccessTokenConfig struct {
	SigningKey []byte
	Issuer string
	Audience string
	TTL time.Duration
	Now func() time.Time
}

func NewAccessTokenService(cfg AccessTokenConfig) (*AccessTokenService, error) {
	if len(cfg.SigningKey) < 32 || strings.TrimSpace(cfg.Issuer) == "" ||
		strings.TrimSpace(cfg.Audience) == "" || cfg.TTL <= 0 {
		return nil, ErrAccessTokenConfig
	}
	if cfg.Now == nil { cfg.Now = time.Now }
	return &AccessTokenService{key: append([]byte(nil), cfg.SigningKey...), issuer: cfg.Issuer,
		audience: cfg.Audience, ttl: cfg.TTL, now: cfg.Now}, nil
}

// Issue signs a compact JWT with HS256. Signing keys must be kept in the deployment
// secret store and shared only by services that are authorized to issue/verify tokens.
func (s *AccessTokenService) Issue(user domain.User) (string, AccessTokenClaims, error) {
	if err := user.Validate(); err != nil { return "", AccessTokenClaims{}, err }
	if !user.CanAuthenticate() { return "", AccessTokenClaims{}, domain.ErrUserInactive }
	now := s.now().UTC()
	claims := AccessTokenClaims{Subject: user.ID, Issuer: s.issuer, Audience: s.audience,
		IssuedAt: now.Unix(), ExpiresAt: now.Add(s.ttl).Unix(), Roles: append([]domain.Role(nil), user.Roles...)}
	header, err := json.Marshal(map[string]string{"alg":"HS256", "typ":"JWT"})
	if err != nil { return "", AccessTokenClaims{}, fmt.Errorf("encode JWT header: %w", err) }
	payload, err := json.Marshal(claims)
	if err != nil { return "", AccessTokenClaims{}, fmt.Errorf("encode JWT claims: %w", err) }
	unsigned := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	return unsigned + "." + s.sign(unsigned), claims, nil
}

func (s *AccessTokenService) Verify(token string) (AccessTokenClaims, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 { return AccessTokenClaims{}, ErrAccessTokenInvalid }
	unsigned := parts[0] + "." + parts[1]
	expected, err := base64.RawURLEncoding.DecodeString(s.sign(unsigned))
	if err != nil { return AccessTokenClaims{}, ErrAccessTokenInvalid }
	provided, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil || subtle.ConstantTimeCompare(expected, provided) != 1 {
		return AccessTokenClaims{}, ErrAccessTokenInvalid
	}
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil { return AccessTokenClaims{}, ErrAccessTokenInvalid }
	var header map[string]string
	if json.Unmarshal(headerBytes, &header) != nil || header["alg"] != "HS256" || header["typ"] != "JWT" {
		return AccessTokenClaims{}, ErrAccessTokenInvalid
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil { return AccessTokenClaims{}, ErrAccessTokenInvalid }
	var claims AccessTokenClaims
	if json.Unmarshal(payload, &claims) != nil || claims.Subject == "" ||
		claims.Issuer != s.issuer || claims.Audience != s.audience ||
		claims.IssuedAt <= 0 || claims.ExpiresAt <= claims.IssuedAt {
		return AccessTokenClaims{}, ErrAccessTokenInvalid
	}
	now := s.now().UTC().Unix()
	if claims.ExpiresAt <= now { return AccessTokenClaims{}, ErrAccessTokenExpired }
	if claims.IssuedAt > now+60 { return AccessTokenClaims{}, ErrAccessTokenInvalid }
	return claims, nil
}

func (s *AccessTokenService) sign(value string) string {
	mac := hmac.New(sha256.New, s.key)
	_, _ = mac.Write([]byte(value))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
