package service

import (
	"context"
	"errors"

	pgxpool "github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/admin/ports"
)

var ErrAdminServiceConfig = errors.New("admin service is not configured")

type AdminService struct {
	db   *pgxpool.Pool
	repo ports.AdminRepository
}

type AdminServiceConfig struct {
	DB   *pgxpool.Pool
	Repo ports.AdminRepository
}

func NewAdminService(cfg AdminServiceConfig) (*AdminService, error) {
	if cfg.DB == nil || cfg.Repo == nil {
		return nil, ErrAdminServiceConfig
	}
	return &AdminService{db: cfg.DB, repo: cfg.Repo}, nil
}

func (s *AdminService) ListDrivers(ctx context.Context, status *string, limit int, offset int) ([]ports.AdminDriver, error) {
	if limit > 100 {
		limit = 100
	}
	return s.repo.ListDrivers(ctx, status, limit, offset)
}

func (s *AdminService) ListRides(ctx context.Context, status *string, limit int, offset int) ([]ports.AdminRide, error) {
	if limit > 100 {
		limit = 100
	}
	return s.repo.ListRides(ctx, status, limit, offset)
}

func (s *AdminService) CancelRide(ctx context.Context, rideID, reason, staffID string) error {
	if rideID == "" || reason == "" || staffID == "" {
		return errors.New("ride ID, reason, and staff ID are required")
	}
	return s.repo.CancelRide(ctx, rideID, reason, staffID)
}

func (s *AdminService) ListPricingRules(ctx context.Context, serviceAreaID *string) ([]ports.PricingRule, error) {
	return s.repo.ListPricingRules(ctx, serviceAreaID)
}

func (s *AdminService) ListPayouts(ctx context.Context, status *string, limit int, offset int) ([]ports.AdminPayout, error) {
	if limit > 100 {
		limit = 100
	}
	return s.repo.ListPayouts(ctx, status, limit, offset)
}

func (s *AdminService) ApprovePayout(ctx context.Context, payoutID, reviewerID string) error {
	if payoutID == "" || reviewerID == "" {
		return errors.New("payout ID and reviewer ID are required")
	}
	return s.repo.ApprovePayout(ctx, payoutID, reviewerID)
}

func (s *AdminService) DriverBalances(ctx context.Context) ([]ports.DriverBalance, error) {
	return s.repo.DriverBalances(ctx)
}

func (s *AdminService) Stats(ctx context.Context) (*ports.AdminStats, error) {
	return s.repo.Stats(ctx)
}
