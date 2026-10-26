package config_test

import (
	"strings"
	"testing"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/config"
)

func setMinimalEnv(t *testing.T) {
	t.Helper()
	t.Setenv("DATABASE_URL", "postgres://test:test@localhost:5432/test?sslmode=disable")
	t.Setenv("APP_ENV", "development")
}

func TestLoadDefaults(t *testing.T) {
	setMinimalEnv(t)

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("unexpected error loading config: %v", err)
	}

	if cfg.AppEnv != "development" {
		t.Errorf("got AppEnv %q, want development", cfg.AppEnv)
	}
	if cfg.HTTPAddr != ":8080" {
		t.Errorf("got HTTPAddr %q, want :8080", cfg.HTTPAddr)
	}
	if cfg.JWTIssuer != "mishwar-api" {
		t.Errorf("got JWTIssuer %q, want mishwar-api", cfg.JWTIssuer)
	}
	if cfg.JWTAudience != "mishwar-clients" {
		t.Errorf("got JWTAudience %q, want mishwar-clients", cfg.JWTAudience)
	}
	if cfg.JWTAccessTTL != 15*time.Minute {
		t.Errorf("got JWTAccessTTL %v, want 15m", cfg.JWTAccessTTL)
	}
	if cfg.RefreshTokenTTL != 720*time.Hour {
		t.Errorf("got RefreshTokenTTL %v, want 720h", cfg.RefreshTokenTTL)
	}
	if cfg.OTPTTL != 5*time.Minute {
		t.Errorf("got OTPTTL %v, want 5m", cfg.OTPTTL)
	}
	if cfg.OTPMaxAttempts != 3 {
		t.Errorf("got OTPMaxAttempts %d, want 3", cfg.OTPMaxAttempts)
	}
	if cfg.OTPRateLimitPhoneMax != 3 {
		t.Errorf("got OTPRateLimitPhoneMax %d, want 3", cfg.OTPRateLimitPhoneMax)
	}
	if cfg.OTPRateLimitIPMax != 10 {
		t.Errorf("got OTPRateLimitIPMax %d, want 10", cfg.OTPRateLimitIPMax)
	}
	if cfg.OTPProvider != "console" {
		t.Errorf("got OTPProvider %q, want console", cfg.OTPProvider)
	}
	if cfg.OTPDevDisplay != false {
		t.Errorf("got OTPDevDisplay %v, want false", cfg.OTPDevDisplay)
	}
	if len(cfg.JWTAccessSecret) < 32 {
		t.Errorf("expected default dev JWT secret >= 32 bytes, got %d", len(cfg.JWTAccessSecret))
	}
	if len(cfg.OTPPepper) < 32 {
		t.Errorf("expected default dev OTP pepper >= 32 bytes, got %d", len(cfg.OTPPepper))
	}
	if len(cfg.OTPRateLimitKey) < 32 {
		t.Errorf("expected default dev OTP limiter key >= 32 bytes, got %d", len(cfg.OTPRateLimitKey))
	}
}

func TestLoadValidation(t *testing.T) {
	tests := []struct {
		name        string
		setup       func(t *testing.T)
		errContains string
	}{
		{
			name: "missing database url",
			setup: func(t *testing.T) {
				t.Setenv("DATABASE_URL", "")
			},
			errContains: "DATABASE_URL is required",
		},
		{
			name: "invalid read header timeout",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("READ_HEADER_TIMEOUT", "invalid")
			},
			errContains: "invalid READ_HEADER_TIMEOUT duration",
		},
		{
			name: "non-positive write timeout",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("WRITE_TIMEOUT", "0s")
			},
			errContains: "invalid WRITE_TIMEOUT duration",
		},
		{
			name: "invalid integer limit",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("OTP_MAX_ATTEMPTS", "not_a_number")
			},
			errContains: "invalid OTP_MAX_ATTEMPTS value",
		},
		{
			name: "negative integer limit",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("OTP_RATE_LIMIT_PHONE_MAX", "-1")
			},
			errContains: "invalid OTP_RATE_LIMIT_PHONE_MAX value",
		},
		{
			name: "invalid boolean dev display",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("OTP_DEV_DISPLAY", "maybe")
			},
			errContains: "invalid OTP_DEV_DISPLAY boolean",
		},
		{
			name: "short custom secret in development",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("JWT_ACCESS_SECRET", "too-short")
			},
			errContains: "JWT_ACCESS_SECRET must be at least 32 bytes",
		},
		{
			name: "production forbids console provider",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("APP_ENV", "production")
				t.Setenv("JWT_ACCESS_SECRET", "prod-secret-must-be-very-long-and-secure-123456789")
				t.Setenv("OTP_PEPPER", "prod-pepper-must-be-very-long-and-secure-123456789")
				t.Setenv("OTP_LIMITER_KEY", "prod-limiter-key-very-long-and-secure-123456789")
				t.Setenv("OTP_PROVIDER", "console")
			},
			errContains: "OTP_PROVIDER=console is forbidden in production",
		},
		{
			name: "production requires explicit secrets",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("APP_ENV", "production")
				t.Setenv("OTP_PROVIDER", "stub")
			},
			errContains: "JWT_ACCESS_SECRET is required in production",
		},
		{
			name: "production rejects dev fallback secret",
			setup: func(t *testing.T) {
				setMinimalEnv(t)
				t.Setenv("APP_ENV", "production")
				t.Setenv("OTP_PROVIDER", "stub")
				t.Setenv("JWT_ACCESS_SECRET", config.DefaultDevJWTAccessSecret)
			},
			errContains: "default JWT_ACCESS_SECRET is forbidden in production",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup(t)
			_, err := config.Load()
			if err == nil {
				t.Fatalf("expected error, got nil")
			}
			if !strings.Contains(err.Error(), tt.errContains) {
				t.Fatalf("error %q does not contain %q", err.Error(), tt.errContains)
			}
		})
	}
}
