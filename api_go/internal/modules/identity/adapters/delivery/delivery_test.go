package delivery_test

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/adapters/delivery"
)

func TestNewDelivery(t *testing.T) {
	discardLogger := slog.New(slog.NewTextHandler(io.Discard, nil))

	tests := []struct {
		name        string
		provider    string
		appEnv      string
		devDisplay  bool
		wantErr     error
		expectError bool
	}{
		{
			name:        "console in development is permitted",
			provider:    "console",
			appEnv:      "development",
			expectError: false,
		},
		{
			name:        "empty provider defaults to console in development",
			provider:    "",
			appEnv:      "development",
			expectError: false,
		},
		{
			name:        "console in production is rejected",
			provider:    "console",
			appEnv:      "production",
			wantErr:     delivery.ErrConsoleInProduction,
			expectError: true,
		},
		{
			name:        "empty provider in production defaults to console and is rejected",
			provider:    "",
			appEnv:      "production",
			wantErr:     delivery.ErrConsoleInProduction,
			expectError: true,
		},
		{
			name:        "stub provider in production is permitted",
			provider:    "stub",
			appEnv:      "production",
			expectError: false,
		},
		{
			name:        "noop provider is permitted",
			provider:    "noop",
			appEnv:      "development",
			expectError: false,
		},
		{
			name:        "unknown provider is rejected",
			provider:    "unsupported-carrier",
			appEnv:      "development",
			wantErr:     delivery.ErrUnsupportedProvider,
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			d, err := delivery.New(tt.provider, tt.appEnv, tt.devDisplay, discardLogger)
			if tt.expectError {
				if err == nil {
					t.Fatalf("expected error, got nil")
				}
				if tt.wantErr != nil && !errors.Is(err, tt.wantErr) {
					t.Fatalf("expected error %v, got %v", tt.wantErr, err)
				}
			} else {
				if err != nil {
					t.Fatalf("unexpected error: %v", err)
				}
				if d == nil {
					t.Fatalf("expected delivery adapter, got nil")
				}
			}
		})
	}
}

func TestSendCode(t *testing.T) {
	discardLogger := slog.New(slog.NewTextHandler(io.Discard, nil))

	t.Run("successful delivery dispatch", func(t *testing.T) {
		d, err := delivery.New("console", "development", true, discardLogger)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if err := d.SendCode(context.Background(), "+967770000001", "123456"); err != nil {
			t.Fatalf("unexpected SendCode error: %v", err)
		}
	})

	t.Run("canceled context aborts delivery", func(t *testing.T) {
		d, err := delivery.New("stub", "development", false, discardLogger)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		ctx, cancel := context.WithCancel(context.Background())
		cancel()

		err = d.SendCode(ctx, "+967770000001", "123456")
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("expected context.Canceled, got %v", err)
		}
	})

	t.Run("deadline exceeded context aborts delivery", func(t *testing.T) {
		d, err := delivery.New("console", "development", false, discardLogger)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(-time.Second))
		defer cancel()

		err = d.SendCode(ctx, "+967770000001", "123456")
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Fatalf("expected context.DeadlineExceeded, got %v", err)
		}
	})
}
