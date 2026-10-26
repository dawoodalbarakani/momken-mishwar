package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/dispatch/ports"
)

type DispatchSettingsRepository struct {
	db *pgxpool.Pool
}

func NewDispatchSettingsRepository(db *pgxpool.Pool) *DispatchSettingsRepository {
	return &DispatchSettingsRepository{db: db}
}

func (r *DispatchSettingsRepository) FindByServiceArea(ctx context.Context, serviceAreaID string) (ports.DispatchSettings, bool, error) {
	if r.db == nil {
		return ports.DispatchSettings{}, false, errors.New("dispatch settings repository: nil database")
	}
	var s ports.DispatchSettings
	err := r.db.QueryRow(ctx, `
		SELECT service_area_id::text, search_radius_m, max_candidates, offer_batch_size,
		       offer_ttl_seconds, search_timeout_seconds, location_max_age_seconds,
		       start_code_ttl_minutes, start_code_max_attempts
		FROM dispatch_settings WHERE service_area_id = $1::uuid`, serviceAreaID).Scan(
		&s.ServiceAreaID, &s.SearchRadiusM, &s.MaxCandidates, &s.OfferBatchSize,
		&s.OfferTTLSeconds, &s.SearchTimeoutSeconds, &s.LocationMaxAgeSeconds,
		&s.StartCodeTTLMinutes, &s.StartCodeMaxAttempts,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return ports.DispatchSettings{}, false, nil
	}
	if err != nil {
		return ports.DispatchSettings{}, false, fmt.Errorf("find dispatch settings: %w", err)
	}
	return s, true, nil
}

type DriverRepository struct {
	db *pgxpool.Pool
}

func NewDriverRepository(db *pgxpool.Pool) *DriverRepository {
	return &DriverRepository{db: db}
}

func (r *DriverRepository) FindOnlineApprovedInArea(ctx context.Context, serviceAreaID string, maxAgeSeconds int, radiusM int, pickupLat, pickupLon float64, limit int) ([]ports.DriverCandidate, error) {
	if r.db == nil {
		return nil, errors.New("driver repository: nil database")
	}
	rows, err := r.db.Query(ctx, `
		SELECT dp.user_id::text,
		       ST_Distance(dp.last_location,
		         ST_SetSRID(ST_MakePoint($3, $4)::geometry, 4326)::geography) AS distance_m
		FROM driver_profiles dp
		JOIN users u ON u.id = dp.user_id
		WHERE u.status = 'ACTIVE'
		  AND dp.is_online = true
		  AND dp.verification_status = 'APPROVED'
		  AND dp.service_area_id = $1::uuid
		  AND dp.last_location IS NOT NULL
		  AND dp.last_location_at > now() - ($2 * interval '1 second')
		  AND NOT EXISTS (
			SELECT 1 FROM rides r2
			WHERE r2.driver_id = dp.user_id
			  AND r2.status IN ('ASSIGNED','ARRIVING','ARRIVED','IN_PROGRESS')
		  )
		  AND ST_DWithin(dp.last_location,
			ST_SetSRID(ST_MakePoint($3, $4)::geometry, 4326)::geography, $5)
		ORDER BY distance_m
		LIMIT $6`,
		serviceAreaID, maxAgeSeconds, pickupLon, pickupLat, radiusM, limit)
	if err != nil {
		return nil, fmt.Errorf("find candidates: %w", err)
	}
	defer rows.Close()
	var candidates []ports.DriverCandidate
	for rows.Next() {
		var c ports.DriverCandidate
		if err := rows.Scan(&c.DriverID, &c.DistanceM); err != nil {
			return nil, err
		}
		candidates = append(candidates, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return candidates, nil
}

func (r *DriverRepository) HasActiveRide(ctx context.Context, driverID string) (bool, error) {
	if r.db == nil {
		return false, errors.New("driver repository: nil database")
	}
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM rides
			WHERE driver_id = $1::uuid
			  AND status IN ('ASSIGNED','ARRIVING','ARRIVED','IN_PROGRESS')
		)`, driverID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check active ride: %w", err)
	}
	return exists, nil
}

func (r *DriverRepository) FindProfile(ctx context.Context, driverID string) (ports.DriverProfile, error) {
	if r.db == nil {
		return ports.DriverProfile{}, errors.New("driver repository: nil database")
	}
	var p ports.DriverProfile
	var verificationStatus, status string
	var isOnline bool
	var serviceAreaID sql.NullString
	err := r.db.QueryRow(ctx, `
		SELECT dp.user_id::text, dp.verification_status, dp.is_online,
		       dp.service_area_id::text, u.status
		FROM driver_profiles dp
		JOIN users u ON u.id = dp.user_id
		WHERE dp.user_id = $1::uuid`, driverID).Scan(
		&p.UserID, &verificationStatus, &isOnline, &serviceAreaID, &status)
	if err != nil {
		return ports.DriverProfile{}, fmt.Errorf("find driver profile: %w", err)
	}
	p.VerificationStatus = verificationStatus
	p.IsOnline = isOnline
	p.ServiceAreaID = serviceAreaID.String
	p.Status = status
	return p, nil
}

type VehicleRepository struct {
	db *pgxpool.Pool
}

func NewVehicleRepository(db *pgxpool.Pool) *VehicleRepository {
	return &VehicleRepository{db: db}
}

func (r *VehicleRepository) FindActiveByDriverAndType(ctx context.Context, vehicleID, driverID, vehicleTypeID string) (bool, error) {
	if r.db == nil {
		return false, errors.New("vehicle repository: nil database")
	}
	var exists bool
	err := r.db.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM vehicles
			WHERE id = $1::uuid
			  AND driver_id = $2::uuid
			  AND vehicle_type_id = $3::uuid
			  AND is_active = true
		)`, vehicleID, driverID, vehicleTypeID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("find vehicle: %w", err)
	}
	return exists, nil
}
