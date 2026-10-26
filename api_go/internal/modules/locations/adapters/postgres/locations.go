package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/locations/ports"
)

type DriverLocationRepository struct {
	db *pgxpool.Pool
}

func NewDriverLocationRepository(db *pgxpool.Pool) *DriverLocationRepository {
	return &DriverLocationRepository{db: db}
}

func (r *DriverLocationRepository) CreateBatch(ctx context.Context, driverID string, updates []ports.DriverLocationUpdate) (int, error) {
	if r.db == nil {
		return 0, errors.New("driver location repository: nil database")
	}
	if len(updates) == 0 {
		return 0, nil
	}

	count := 0
	for _, u := range updates {
		_, err := r.db.Exec(ctx, `
			INSERT INTO driver_location_updates (driver_id, ride_id, location, accuracy_m, speed_mps, heading_deg, recorded_at, received_at)
			VALUES ($1::uuid, $2::uuid, ST_SetSRID(ST_MakePoint($3, $4)::geometry, 4326)::geography, $5, $6, $7, $8, now())`,
			driverID, nullUUID(u.RideID), u.LocationLon, u.LocationLat,
			nullFloat64Ptr(u.AccuracyM), nullFloat64Ptr(u.SpeedMps), nullFloat64Ptr(u.HeadingDeg), u.RecordedAt)
		if err != nil {
			return count, fmt.Errorf("insert location update: %w", err)
		}
		count++
	}
	return count, nil
}

func (r *DriverLocationRepository) UpdateLastLocation(ctx context.Context, driverID string, lat, lon float64, accuracyM *float64, recordedAt string) error {
	if r.db == nil {
		return errors.New("driver location repository: nil database")
	}
	_, err := r.db.Exec(ctx, `
		UPDATE driver_profiles
		SET last_location = ST_SetSRID(ST_MakePoint($2, $3)::geometry, 4326)::geography,
		    last_location_at = $4,
		    last_location_accuracy_m = $5,
		    updated_at = now()
		WHERE user_id = $1::uuid`, driverID, lon, lat, recordedAt, nullFloat64Ptr(accuracyM))
	if err != nil {
		return fmt.Errorf("update last location: %w", err)
	}
	return nil
}

func (r *DriverLocationRepository) Latest(ctx context.Context, driverID string) (*ports.DriverLocation, error) {
	if r.db == nil {
		return nil, errors.New("driver location repository: nil database")
	}
	var lat, lon float64
	var updatedAt sql.NullTime
	err := r.db.QueryRow(ctx, `
		SELECT ST_Y(last_location::geometry), ST_X(last_location::geometry), last_location_at
		FROM driver_profiles WHERE user_id = $1::uuid`, driverID).Scan(&lat, &lon, &updatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("latest location: %w", err)
	}
	loc := &ports.DriverLocation{
		LocationLat: lat,
		LocationLon: lon,
		UpdatedAt:   nullTimeStr(updatedAt),
	}
	if updatedAt.Valid {
		ageSec := int64(time.Since(updatedAt.Time.UTC()).Seconds())
		loc.AgeSec = &ageSec
	}
	return loc, nil
}

func nullUUID(s *string) interface{} {
	if s == nil || *s == "" {
		return nil
	}
	return *s
}

func nullFloat64Ptr(f *float64) interface{} {
	if f == nil {
		return nil
	}
	return *f
}

func nullTimeStr(nt sql.NullTime) string {
	if !nt.Valid {
		return ""
	}
	return nt.Time.UTC().Format(time.RFC3339Nano)
}
