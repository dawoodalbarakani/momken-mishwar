package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	// DefaultDevJWTAccessSecret is used ONLY in non-production environments when JWT_ACCESS_SECRET is omitted.
	DefaultDevJWTAccessSecret = "dev-only-jwt-access-secret-32-bytes-minimum!"

	// DefaultDevOTPPepper is used ONLY in non-production environments when OTP_PEPPER is omitted.
	DefaultDevOTPPepper = "dev-only-otp-pepper-secret-32-bytes-minimum!!"

	// DefaultDevOTPRateLimitKey is used ONLY in non-production environments when OTP_LIMITER_KEY is omitted.
	DefaultDevOTPRateLimitKey = "dev-only-otp-rate-limit-key-32-bytes-minimum!"
)

// Config represents runtime configuration loaded from environment variables.
type Config struct {
	AppEnv            string
	HTTPAddr          string
	DatabaseURL       string
	ReadHeaderTimeout time.Duration
	ReadTimeout       time.Duration
	WriteTimeout      time.Duration
	IdleTimeout       time.Duration
	ShutdownTimeout   time.Duration

	// Authentication & JWT Access Tokens
	JWTAccessSecret []byte
	JWTIssuer       string
	JWTAudience     string
	JWTAccessTTL    time.Duration

	// Refresh Tokens
	RefreshTokenTTL time.Duration

	// OTP Challenge Service
	OTPPepper      []byte
	OTPTTL         time.Duration
	OTPMaxAttempts int

	// OTP Rate Limiter
	OTPRateLimitKey      []byte
	OTPRateLimitWindow   time.Duration
	OTPRateLimitPhoneMax int
	OTPRateLimitIPMax    int

	// OTP Delivery
	OTPProvider   string
	OTPDevDisplay bool
}

// Load reads and validates configuration from environment variables.
func Load() (Config, error) {
	cfg := Config{
		AppEnv:      env("APP_ENV", "development"),
		HTTPAddr:    env("HTTP_ADDR", ":8080"),
		DatabaseURL: os.Getenv("DATABASE_URL"),
		JWTIssuer:   env("JWT_ISSUER", "mishwar-api"),
		JWTAudience: env("JWT_AUDIENCE", "mishwar-clients"),
		OTPProvider: env("OTP_PROVIDER", "console"),
	}

	if cfg.DatabaseURL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}

	isProduction := strings.EqualFold(cfg.AppEnv, "production")

	// Timeout fields
	timeoutFields := []struct {
		name     string
		target   *time.Duration
		fallback string
	}{
		{"READ_HEADER_TIMEOUT", &cfg.ReadHeaderTimeout, "5s"},
		{"READ_TIMEOUT", &cfg.ReadTimeout, "10s"},
		{"WRITE_TIMEOUT", &cfg.WriteTimeout, "15s"},
		{"IDLE_TIMEOUT", &cfg.IdleTimeout, "60s"},
		{"SHUTDOWN_TIMEOUT", &cfg.ShutdownTimeout, "10s"},
		{"JWT_ACCESS_TTL", &cfg.JWTAccessTTL, "15m"},
		{"JWT_REFRESH_TTL", &cfg.RefreshTokenTTL, "720h"},
		{"OTP_TTL", &cfg.OTPTTL, "5m"},
		{"OTP_RATE_LIMIT_WINDOW", &cfg.OTPRateLimitWindow, "15m"},
	}
	for _, f := range timeoutFields {
		d, err := time.ParseDuration(env(f.name, f.fallback))
		if err != nil || d <= 0 {
			return Config{}, fmt.Errorf("invalid %s duration", f.name)
		}
		*f.target = d
	}

	// Integer limits
	intFields := []struct {
		name     string
		target   *int
		fallback int
	}{
		{"OTP_MAX_ATTEMPTS", &cfg.OTPMaxAttempts, 3},
		{"OTP_RATE_LIMIT_PHONE_MAX", &cfg.OTPRateLimitPhoneMax, 3},
		{"OTP_RATE_LIMIT_IP_MAX", &cfg.OTPRateLimitIPMax, 10},
	}
	for _, f := range intFields {
		valStr := env(f.name, "")
		if valStr == "" {
			*f.target = f.fallback
		} else {
			val, err := strconv.Atoi(valStr)
			if err != nil || val <= 0 {
				return Config{}, fmt.Errorf("invalid %s value: must be positive integer", f.name)
			}
			*f.target = val
		}
	}

	// Boolean options
	if devDisplayStr := os.Getenv("OTP_DEV_DISPLAY"); devDisplayStr != "" {
		parsed, err := strconv.ParseBool(devDisplayStr)
		if err != nil {
			return Config{}, fmt.Errorf("invalid OTP_DEV_DISPLAY boolean: %w", err)
		}
		cfg.OTPDevDisplay = parsed
	}

	// Secrets validation
	jwtSecret, err := resolveSecret("JWT_ACCESS_SECRET", DefaultDevJWTAccessSecret, isProduction)
	if err != nil {
		return Config{}, err
	}
	cfg.JWTAccessSecret = jwtSecret

	pepperSecret, err := resolveSecret("OTP_PEPPER", DefaultDevOTPPepper, isProduction)
	if err != nil {
		return Config{}, err
	}
	cfg.OTPPepper = pepperSecret

	limiterKey, err := resolveSecret("OTP_LIMITER_KEY", DefaultDevOTPRateLimitKey, isProduction)
	if err != nil {
		return Config{}, err
	}
	cfg.OTPRateLimitKey = limiterKey

	// Production delivery check
	if isProduction && strings.EqualFold(cfg.OTPProvider, "console") {
		return Config{}, errors.New("OTP_PROVIDER=console is forbidden in production")
	}

	return cfg, nil
}

func resolveSecret(envKey, devDefault string, isProduction bool) ([]byte, error) {
	val := os.Getenv(envKey)
	if val == "" {
		if isProduction {
			return nil, fmt.Errorf("%s is required in production", envKey)
		}
		return []byte(devDefault), nil
	}
	if len(val) < 32 {
		return nil, fmt.Errorf("%s must be at least 32 bytes", envKey)
	}
	if isProduction && val == devDefault {
		return nil, fmt.Errorf("default %s is forbidden in production", envKey)
	}
	return []byte(val), nil
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
