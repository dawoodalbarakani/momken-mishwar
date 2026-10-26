package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/barakanid96/momken-mishwar/api_go/internal/config"
	"github.com/barakanid96/momken-mishwar/api_go/internal/httpapi"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/adapters/delivery"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/adapters/postgres"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
	"github.com/barakanid96/momken-mishwar/api_go/internal/store"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg, err := config.Load()
	if err != nil {
		logger.Error("load configuration", "error", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	db, err := store.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("connect database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	// Initialize identity storage adapters
	userRepo := postgres.NewUserRepository(db)
	otpRepo := postgres.NewOTPRepository(db)
	refreshRepo := postgres.NewRefreshTokenRepository(db)
	otpLimiter, err := postgres.NewOTPRequestLimiter(
		db,
		cfg.OTPRateLimitKey,
		cfg.OTPRateLimitWindow,
		cfg.OTPRateLimitPhoneMax,
		cfg.OTPRateLimitIPMax,
	)
	if err != nil {
		logger.Error("initialize OTP request limiter", "error", err)
		os.Exit(1)
	}

	// Initialize OTP delivery adapter
	otpDelivery, err := delivery.New(cfg.OTPProvider, cfg.AppEnv, cfg.OTPDevDisplay, logger)
	if err != nil {
		logger.Error("initialize OTP delivery provider", "error", err)
		os.Exit(1)
	}

	// Initialize identity domain services
	accessTokens, err := service.NewAccessTokenService(service.AccessTokenConfig{
		SigningKey: cfg.JWTAccessSecret,
		Issuer:     cfg.JWTIssuer,
		Audience:   cfg.JWTAudience,
		TTL:        cfg.JWTAccessTTL,
	})
	if err != nil {
		logger.Error("initialize access token service", "error", err)
		os.Exit(1)
	}

	refreshTokens, err := service.NewRefreshTokenService(service.RefreshTokenServiceConfig{
		Repository: refreshRepo,
		TTL:        cfg.RefreshTokenTTL,
	})
	if err != nil {
		logger.Error("initialize refresh token service", "error", err)
		os.Exit(1)
	}

	otpService, err := service.NewOTPService(service.OTPServiceConfig{
		Repository:  otpRepo,
		Delivery:    otpDelivery,
		Limiter:     otpLimiter,
		Pepper:      cfg.OTPPepper,
		TTL:         cfg.OTPTTL,
		MaxAttempts: cfg.OTPMaxAttempts,
	})
	if err != nil {
		logger.Error("initialize OTP service", "error", err)
		os.Exit(1)
	}

	sessionService, err := service.NewSessionService(service.SessionServiceConfig{
		OTP:           otpService,
		Users:         userRepo,
		RefreshTokens: refreshTokens,
		AccessTokens:  accessTokens,
	})
	if err != nil {
		logger.Error("initialize session service", "error", err)
		os.Exit(1)
	}

	refreshSessionService, err := service.NewRefreshSessionService(service.RefreshSessionServiceConfig{
		Users:         userRepo,
		RefreshTokens: refreshTokens,
		AccessTokens:  accessTokens,
	})
	if err != nil {
		logger.Error("initialize refresh session service", "error", err)
		os.Exit(1)
	}

	authHandlers := &httpapi.AuthHandlers{
		OTP:             otpService,
		Sessions:        sessionService,
		RefreshSessions: refreshSessionService,
		RefreshTokens:   refreshTokens,
	}

	router := httpapi.NewWithConfig(logger, db, httpapi.RouterConfig{
		Auth:   authHandlers,
		Tokens: accessTokens,
		Users:  userRepo,
	})

	server := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           router,
		ReadHeaderTimeout: cfg.ReadHeaderTimeout,
		ReadTimeout:       cfg.ReadTimeout,
		WriteTimeout:      cfg.WriteTimeout,
		IdleTimeout:       cfg.IdleTimeout,
	}

	go func() {
		logger.Info("api_go listening", "addr", cfg.HTTPAddr, "env", cfg.AppEnv)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("http server failed", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		_ = server.Close()
	}
	logger.Info("api_go stopped")
}
