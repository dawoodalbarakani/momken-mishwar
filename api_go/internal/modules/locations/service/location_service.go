package service

import (
	"context"
	"errors"
	"fmt"

	pgxpool "github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/locations/ports"
)

var ErrLocationsServiceConfig = errors.New("locations service is not configured")

type LocationService struct {
	db   *pgxpool.Pool
	repo ports.DriverLocationRepository
}

type LocationServiceConfig struct {
	DB   *pgxpool.Pool
	Repo ports.DriverLocationRepository
}

func NewLocationService(cfg LocationServiceConfig) (*LocationService, error) {
	if cfg.DB == nil || cfg.Repo == nil {
		return nil, ErrLocationsServiceConfig
	}
	return &LocationService{db: cfg.DB, repo: cfg.Repo}, nil
}

type LocationBatchParams struct {
	DriverID string
	Updates  []ports.DriverLocationUpdate
}

func (s *LocationService) UpdateBatch(ctx context.Context, params LocationBatchParams) (int, error) {
	if params.DriverID == "" || len(params.Updates) == 0 {
		return 0, errors.New("driver ID and updates are required")
	}
	count, err := s.repo.CreateBatch(ctx, params.DriverID, params.Updates)
	if err != nil {
		return 0, fmt.Errorf("create location updates: %w", err)
	}
	// Update last location from the latest update
	last := params.Updates[len(params.Updates)-1]
	var accuracyM *float64
	if last.AccuracyM != nil {
		accuracyM = last.AccuracyM
	}
	if err := s.repo.UpdateLastLocation(ctx, params.DriverID, last.LocationLat, last.LocationLon, accuracyM, last.RecordedAt); err != nil {
		return 0, fmt.Errorf("update last location: %w", err)
	}
	return count, nil
}

func (s *LocationService) Latest(ctx context.Context, driverID string) (*ports.DriverLocation, error) {
	return s.repo.Latest(ctx, driverID)
}
