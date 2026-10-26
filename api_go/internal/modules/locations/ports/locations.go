package ports

import (
	"context"
)

type DriverLocationUpdate struct {
	DriverID    string
	RideID      *string
	LocationLat float64
	LocationLon float64
	AccuracyM   *float64
	SpeedMps    *float64
	HeadingDeg  *float64
	RecordedAt  string
}

type DriverLocationRepository interface {
	CreateBatch(ctx context.Context, driverID string, updates []DriverLocationUpdate) (int, error)
	UpdateLastLocation(ctx context.Context, driverID string, lat, lon float64, accuracyM *float64, recordedAt string) error
	Latest(ctx context.Context, driverID string) (*DriverLocation, error)
}

type DriverLocation struct {
	LocationLat float64
	LocationLon float64
	UpdatedAt   string
	AgeSec      *int64
}
