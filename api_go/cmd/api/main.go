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
	adminpostgres "github.com/barakanid96/momken-mishwar/api_go/internal/modules/admin/adapters/postgres"
	adminservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/admin/service"
	dispatchpostgres "github.com/barakanid96/momken-mishwar/api_go/internal/modules/dispatch/adapters/postgres"
	dispatchservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/dispatch/service"
	driverspostgres "github.com/barakanid96/momken-mishwar/api_go/internal/modules/drivers/adapters/postgres"
	driversservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/drivers/service"
	idempostgres "github.com/barakanid96/momken-mishwar/api_go/internal/modules/idempotency/adapters/postgres"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/adapters/delivery"
	identitypostgres "github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/adapters/postgres"
	identityservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
	locationspostgres "github.com/barakanid96/momken-mishwar/api_go/internal/modules/locations/adapters/postgres"
	locationsservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/locations/service"
	paymentspostgres "github.com/barakanid96/momken-mishwar/api_go/internal/modules/payments/adapters/postgres"
	paymentsservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/payments/service"
	pricingservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/pricing/service"
	ridespostgres "github.com/barakanid96/momken-mishwar/api_go/internal/modules/rides/adapters/postgres"
	ridesservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/rides/service"
	tripsservice "github.com/barakanid96/momken-mishwar/api_go/internal/modules/trips/service"
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

	// Identity adapters
	userRepo := identitypostgres.NewUserRepository(db)
	otpRepo := identitypostgres.NewOTPRepository(db)
	refreshRepo := identitypostgres.NewRefreshTokenRepository(db)
	otpLimiter, err := identitypostgres.NewOTPRequestLimiter(
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

	otpDelivery, err := delivery.New(cfg.OTPProvider, cfg.AppEnv, cfg.OTPDevDisplay, logger)
	if err != nil {
		logger.Error("initialize OTP delivery provider", "error", err)
		os.Exit(1)
	}

	accessTokens, err := identityservice.NewAccessTokenService(identityservice.AccessTokenConfig{
		SigningKey: cfg.JWTAccessSecret,
		Issuer:     cfg.JWTIssuer,
		Audience:   cfg.JWTAudience,
		TTL:        cfg.JWTAccessTTL,
	})
	if err != nil {
		logger.Error("initialize access token service", "error", err)
		os.Exit(1)
	}

	refreshTokens, err := identityservice.NewRefreshTokenService(identityservice.RefreshTokenServiceConfig{
		Repository: refreshRepo,
		TTL:        cfg.RefreshTokenTTL,
	})
	if err != nil {
		logger.Error("initialize refresh token service", "error", err)
		os.Exit(1)
	}

	otpService, err := identityservice.NewOTPService(identityservice.OTPServiceConfig{
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

	sessionService, err := identityservice.NewSessionService(identityservice.SessionServiceConfig{
		OTP:           otpService,
		Users:         userRepo,
		RefreshTokens: refreshTokens,
		AccessTokens:  accessTokens,
	})
	if err != nil {
		logger.Error("initialize session service", "error", err)
		os.Exit(1)
	}

	// Idempotency store
	idemStore := idempostgres.NewIdempotencyStore(db)

	// Pricing service
	pricingSvc, err := pricingservice.NewPricingService(db)
	if err != nil {
		logger.Error("initialize pricing service", "error", err)
		os.Exit(1)
	}

	// Rides service
	rideRepo := ridespostgres.NewRideRepository(db)
	rideSvc, err := ridesservice.NewRideService(ridesservice.RideServiceConfig{
		DB:              db,
		Repo:            rideRepo,
		Idempotency:     idemStore,
		Pricing:         pricingSvc,
		StartCodeSecret: []byte(cfg.JWTAccessSecret),
		Now:             nil,
	})
	if err != nil {
		logger.Error("initialize ride service", "error", err)
		os.Exit(1)
	}

	// Dispatch service
	dispatchOfferRepo := dispatchpostgres.NewRideOfferRepository(db)
	dispatchSettingsRepo := dispatchpostgres.NewDispatchSettingsRepository(db)
	dispatchDriverRepo := dispatchpostgres.NewDriverRepository(db)
	dispatchVehicleRepo := dispatchpostgres.NewVehicleRepository(db)

	dispatchSvc, err := dispatchservice.NewDispatchService(dispatchservice.DispatchServiceConfig{
		DB:              db,
		OfferRepo:       dispatchOfferRepo,
		SettingsRepo:    dispatchSettingsRepo,
		DriverRepo:      dispatchDriverRepo,
		VehicleRepo:     dispatchVehicleRepo,
		RideRepo:        rideRepo,
		StartCodeSecret: []byte(cfg.JWTAccessSecret),
		Now:             nil,
	})
	if err != nil {
		logger.Error("initialize dispatch service", "error", err)
		os.Exit(1)
	}

	// Trips service
	tripRepo := ridespostgres.NewRideRepository(db)
	ledgerRepo := paymentspostgres.NewLedgerRepository(db)

	tripSvc, err := tripsservice.NewTripService(tripsservice.TripServiceConfig{
		DB:              db,
		Repo:            tripRepo,
		LedgerClient:    ledgerRepo,
		StartCodeSecret: []byte(cfg.JWTAccessSecret),
		Now:             nil,
	})
	if err != nil {
		logger.Error("initialize trip service", "error", err)
		os.Exit(1)
	}

	// Drivers service
	driversRepo := driverspostgres.NewDriverRepository(db)
	vehiclesRepo := driverspostgres.NewVehicleRepository(db)
	customersRepo := driverspostgres.NewCustomerRepository(db)
	savedPlacesRepo := driverspostgres.NewSavedPlaceRepository(db)

	driversSvc, err := driversservice.NewDriverService(driversservice.DriverServiceConfig{
		DB:        db,
		Repo:      driversRepo,
		VehRepo:   vehiclesRepo,
		CustRepo:  customersRepo,
		SavedRepo: savedPlacesRepo,
	})
	if err != nil {
		logger.Error("initialize drivers service", "error", err)
		os.Exit(1)
	}

	// Payments service
	paymentRepo := paymentspostgres.NewPaymentRepository(db)
	payoutRepo := paymentspostgres.NewPayoutRepository(db)

	paymentsSvc, err := paymentsservice.NewPaymentService(paymentsservice.PaymentServiceConfig{
		DB:         db,
		Repo:       paymentRepo,
		Ledger:     ledgerRepo,
		PayoutRepo: payoutRepo,
	})
	if err != nil {
		logger.Error("initialize payments service", "error", err)
		os.Exit(1)
	}

	// Locations service
	locationRepo := locationspostgres.NewDriverLocationRepository(db)
	locationsSvc, err := locationsservice.NewLocationService(locationsservice.LocationServiceConfig{
		DB:   db,
		Repo: locationRepo,
	})
	if err != nil {
		logger.Error("initialize locations service", "error", err)
		os.Exit(1)
	}

	// Admin service
	adminRepo := adminpostgres.NewAdminRepository(db)
	adminSvc, err := adminservice.NewAdminService(adminservice.AdminServiceConfig{
		DB:   db,
		Repo: adminRepo,
	})
	if err != nil {
		logger.Error("initialize admin service", "error", err)
		os.Exit(1)
	}

	authHandlers := &httpapi.AuthHandlers{
		OTP:           otpService,
		Sessions:      sessionService,
		RefreshTokens: refreshTokens,
	}

	router := httpapi.NewWithConfig(logger, db, httpapi.RouterConfig{
		Auth:        authHandlers,
		Tokens:      accessTokens,
		Users:       userRepo,
		RideService: rideSvc,
		DispatchSvc: dispatchSvc,
		TripService: tripSvc,
		DriverSvc:   driversSvc,
		PaymentSvc:  paymentsSvc,
		LocationSvc: locationsSvc,
		AdminSvc:    adminSvc,
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
