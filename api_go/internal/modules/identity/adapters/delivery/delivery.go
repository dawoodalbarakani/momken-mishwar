package delivery

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
)

var (
	// ErrConsoleInProduction is returned when console delivery is configured in production.
	ErrConsoleInProduction = errors.New("OTP console provider is forbidden in production")

	// ErrUnsupportedProvider is returned when an unknown delivery provider is specified.
	ErrUnsupportedProvider = errors.New("unsupported OTP delivery provider")
)

// Delivery implements service.OTPDelivery for development, testing, and production stubs.
type Delivery struct {
	provider   string
	devDisplay bool
	logger     *slog.Logger
}

// New creates an OTPDelivery adapter based on provider name and runtime environment.
// In production, console delivery is strictly rejected to prevent secret leakage.
func New(provider, appEnv string, devDisplay bool, logger *slog.Logger) (service.OTPDelivery, error) {
	normalized := strings.ToLower(strings.TrimSpace(provider))
	if normalized == "" {
		normalized = "console"
	}

	if strings.EqualFold(appEnv, "production") && normalized == "console" {
		return nil, ErrConsoleInProduction
	}

	if logger == nil {
		logger = slog.Default()
	}

	switch normalized {
	case "console", "stub", "noop":
		return &Delivery{
			provider:   normalized,
			devDisplay: devDisplay,
			logger:     logger,
		}, nil
	default:
		return nil, fmt.Errorf("%w: %q", ErrUnsupportedProvider, provider)
	}
}

// SendCode dispatches the OTP code or logs it depending on environment configuration.
func (d *Delivery) SendCode(ctx context.Context, phoneE164, code string) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	if d.provider == "stub" || d.provider == "noop" {
		return nil
	}

	if d.devDisplay {
		d.logger.Warn("[OTP DEV] delivery code", "phone", phoneE164, "code", code)
	} else {
		d.logger.Info("[OTP] delivery dispatched", "phone", phoneE164, "code", "[REDACTED]")
	}
	return nil
}
