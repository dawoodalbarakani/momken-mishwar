package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/drivers/ports"
)

type DriverRepository struct {
	db *pgxpool.Pool
}

func NewDriverRepository(db *pgxpool.Pool) *DriverRepository {
	return &DriverRepository{db: db}
}

func (r *DriverRepository) FindByUserID(ctx context.Context, userID string) (ports.DriverProfile, bool, error) {
	if r.db == nil {
		return ports.DriverProfile{}, false, errors.New("driver repository: nil database")
	}
	var p ports.DriverProfile
	var verificationStatus string
	var isOnline bool
	var serviceAreaID sql.NullString
	var ratingAvg sql.NullFloat64
	var lastLocationLat, lastLocationLon sql.NullFloat64
	var lastLocationAt sql.NullTime
	var lastLocationAccuracyM sql.NullFloat64

	err := r.db.QueryRow(ctx, `
		SELECT dp.user_id::text, dp.full_name, dp.service_area_id::text,
		       dp.verification_status, dp.is_online, dp.last_location,
		       dp.last_location_at, dp.last_location_accuracy_m,
		       dp.rating_avg, dp.rating_count, u.status
		FROM driver_profiles dp
		JOIN users u ON u.id = dp.user_id
		WHERE dp.user_id = $1::uuid`, userID).Scan(
		&p.UserID, &p.FullName, &serviceAreaID,
		&verificationStatus, &isOnline,
		&lastLocationLat, &lastLocationLon, &lastLocationAt, &lastLocationAccuracyM,
		&ratingAvg, &p.RatingCount, &p.Status,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return ports.DriverProfile{}, false, nil
	}
	if err != nil {
		return ports.DriverProfile{}, false, fmt.Errorf("find driver profile: %w", err)
	}
	p.VerificationStatus = verificationStatus
	p.IsOnline = isOnline
	p.ServiceAreaID = serviceAreaID.String
	if lastLocationLat.Valid && lastLocationLon.Valid {
		p.LastLocationLat = &lastLocationLat.Float64
		p.LastLocationLon = &lastLocationLon.Float64
	}
	if lastLocationAt.Valid {
		p.LastLocationAt = strPtr(lastLocationAt.Time.UTC().Format(time.RFC3339Nano))
	}
	if lastLocationAccuracyM.Valid {
		p.LastLocationAccuracyM = &lastLocationAccuracyM.Float64
	}
	if ratingAvg.Valid {
		p.RatingAvg = &ratingAvg.Float64
	}
	return p, true, nil
}

func (r *DriverRepository) SetOnline(ctx context.Context, userID string, isOnline bool) (ports.DriverProfile, error) {
	if r.db == nil {
		return ports.DriverProfile{}, errors.New("driver repository: nil database")
	}
	var p ports.DriverProfile
	err := r.db.QueryRow(ctx, `
		UPDATE driver_profiles SET is_online = $2, updated_at = now()
		WHERE user_id = $1::uuid
		RETURNING user_id::text, full_name, service_area_id::text, verification_status,
		          is_online, last_location_at, rating_avg, rating_count`,
		userID, isOnline).Scan(
		&p.UserID, &p.FullName, &p.ServiceAreaID, &p.VerificationStatus,
		&p.IsOnline, &p.LastLocationAt, &p.RatingAvg, &p.RatingCount,
	)
	if err != nil {
		return ports.DriverProfile{}, fmt.Errorf("set online: %w", err)
	}
	p.IsOnline = isOnline
	return p, nil
}

func (r *DriverRepository) List(ctx context.Context, serviceAreaID *string, limit int, offset int) ([]ports.DriverProfile, error) {
	if r.db == nil {
		return nil, errors.New("driver repository: nil database")
	}
	query := `
		SELECT dp.user_id::text, dp.full_name, dp.service_area_id::text,
		       dp.verification_status, dp.is_online, dp.rating_avg, dp.rating_count
		FROM driver_profiles dp`
	args := []interface{}{}
	argIdx := 1
	if serviceAreaID != nil {
		query += " WHERE dp.service_area_id = $" + argNum(argIdx)
		args = append(args, *serviceAreaID)
		argIdx++
	}
	query += " LIMIT $" + argNum(argIdx)
	args = append(args, limit)
	argIdx++
	query += " OFFSET $" + argNum(argIdx)
	args = append(args, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list drivers: %w", err)
	}
	defer rows.Close()

	var profiles []ports.DriverProfile
	for rows.Next() {
		var p ports.DriverProfile
		var verificationStatus string
		var isOnline bool
		var ratingAvg sql.NullFloat64
		if err := rows.Scan(&p.UserID, &p.FullName, &p.ServiceAreaID, &verificationStatus,
			&isOnline, &ratingAvg, &p.RatingCount); err != nil {
			return nil, err
		}
		p.VerificationStatus = verificationStatus
		p.IsOnline = isOnline
		if ratingAvg.Valid {
			p.RatingAvg = &ratingAvg.Float64
		}
		profiles = append(profiles, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return profiles, nil
}

type VehicleRepository struct {
	db *pgxpool.Pool
}

func NewVehicleRepository(db *pgxpool.Pool) *VehicleRepository {
	return &VehicleRepository{db: db}
}

func (r *VehicleRepository) Create(ctx context.Context, vehicle ports.Vehicle) (ports.Vehicle, error) {
	if r.db == nil {
		return ports.Vehicle{}, errors.New("vehicle repository: nil database")
	}
	var v ports.Vehicle
	err := r.db.QueryRow(ctx, `
		INSERT INTO vehicles (driver_id, vehicle_type_id, plate_number, make, model, year, color, is_active)
		VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6, $7, true)
		RETURNING id::text, driver_id::text, vehicle_type_id::text, plate_number,
		          make, model, year, color, is_active, created_at, updated_at`,
		vehicle.DriverID, vehicle.VehicleTypeID, vehicle.PlateNumber,
		nullStrPtr(vehicle.Make), nullStrPtr(vehicle.Model),
		nullIntPtr(vehicle.Year), nullStrPtr(vehicle.Color),
	).Scan(
		&v.ID, &v.DriverID, &v.VehicleTypeID, &v.PlateNumber,
		&v.Make, &v.Model, &v.Year, &v.Color, &v.IsActive,
		&v.CreatedAt, &v.UpdatedAt,
	)
	if err != nil {
		return ports.Vehicle{}, fmt.Errorf("create vehicle: %w", err)
	}
	return v, nil
}

func (r *VehicleRepository) ListForDriver(ctx context.Context, driverID string) ([]ports.Vehicle, error) {
	if r.db == nil {
		return nil, errors.New("vehicle repository: nil database")
	}
	rows, err := r.db.Query(ctx, `
		SELECT id::text, driver_id::text, vehicle_type_id::text, plate_number,
		       make, model, year, color, is_active, created_at, updated_at
		FROM vehicles WHERE driver_id = $1::uuid ORDER BY created_at DESC`, driverID)
	if err != nil {
		return nil, fmt.Errorf("list vehicles: %w", err)
	}
	defer rows.Close()

	var vehicles []ports.Vehicle
	for rows.Next() {
		var v ports.Vehicle
		if err := rows.Scan(&v.ID, &v.DriverID, &v.VehicleTypeID, &v.PlateNumber,
			&v.Make, &v.Model, &v.Year, &v.Color, &v.IsActive, &v.CreatedAt, &v.UpdatedAt); err != nil {
			return nil, err
		}
		vehicles = append(vehicles, v)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return vehicles, nil
}

type CustomerRepository struct {
	db *pgxpool.Pool
}

func NewCustomerRepository(db *pgxpool.Pool) *CustomerRepository {
	return &CustomerRepository{db: db}
}

func (r *CustomerRepository) GetOrCreate(ctx context.Context, userID string) (ports.CustomerProfile, error) {
	if r.db == nil {
		return ports.CustomerProfile{}, errors.New("customer repository: nil database")
	}
	var p ports.CustomerProfile
	err := r.db.QueryRow(ctx, `
		INSERT INTO customer_profiles (user_id)
		VALUES ($1::uuid)
		ON CONFLICT (user_id) DO NOTHING
		RETURNING user_id::text, created_at`, userID).Scan(&p.UserID, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		// Already existed, select it
		err = r.db.QueryRow(ctx, `SELECT user_id::text, created_at FROM customer_profiles WHERE user_id = $1::uuid`, userID).Scan(&p.UserID, &p.CreatedAt)
		if err != nil {
			return ports.CustomerProfile{}, fmt.Errorf("get customer profile: %w", err)
		}
		return p, nil
	}
	if err != nil {
		return ports.CustomerProfile{}, fmt.Errorf("create customer profile: %w", err)
	}
	return p, nil
}

type SavedPlaceRepository struct {
	db *pgxpool.Pool
}

func NewSavedPlaceRepository(db *pgxpool.Pool) *SavedPlaceRepository {
	return &SavedPlaceRepository{db: db}
}

func (r *SavedPlaceRepository) List(ctx context.Context, customerID string) ([]ports.SavedPlace, error) {
	if r.db == nil {
		return nil, errors.New("saved place repository: nil database")
	}
	rows, err := r.db.Query(ctx, `
		SELECT id::text, customer_id::text, label, address_text,
		       ST_X(location::geometry), ST_Y(location::geometry), created_at
		FROM saved_places WHERE customer_id = $1::uuid ORDER BY created_at DESC`, customerID)
	if err != nil {
		return nil, fmt.Errorf("list saved places: %w", err)
	}
	defer rows.Close()

	var places []ports.SavedPlace
	for rows.Next() {
		var p ports.SavedPlace
		var addressText sql.NullString
		if err := rows.Scan(&p.ID, &p.CustomerID, &p.Label, &addressText,
			&p.LocationLat, &p.LocationLon, &p.CreatedAt); err != nil {
			return nil, err
		}
		if addressText.Valid {
			p.AddressText = strPtr(addressText.String)
		}
		places = append(places, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return places, nil
}

func (r *SavedPlaceRepository) Create(ctx context.Context, place ports.SavedPlace) (ports.SavedPlace, error) {
	if r.db == nil {
		return ports.SavedPlace{}, errors.New("saved place repository: nil database")
	}
	var p ports.SavedPlace
	err := r.db.QueryRow(ctx, `
		INSERT INTO saved_places (customer_id, label, address_text, location)
		VALUES ($1::uuid, $2, $3,
			ST_SetSRID(ST_MakePoint($4, $5)::geometry, 4326)::geography)
		RETURNING id::text, customer_id::text, label, address_text,
		          ST_X(location::geometry), ST_Y(location::geometry), created_at`,
		place.CustomerID, place.Label, nullStrPtr(place.AddressText),
		place.LocationLon, place.LocationLat,
	).Scan(
		&p.ID, &p.CustomerID, &p.Label, &p.AddressText,
		&p.LocationLat, &p.LocationLon, &p.CreatedAt,
	)
	if err != nil {
		return ports.SavedPlace{}, fmt.Errorf("create saved place: %w", err)
	}
	return p, nil
}

func argNum(n int) string { return fmt.Sprintf("$%d", n) }

func nullStrPtr(s *string) interface{} {
	if s == nil {
		return nil
	}
	return *s
}

func nullIntPtr(i *int) interface{} {
	if i == nil {
		return nil
	}
	return *i
}

func strPtr(s string) *string { return &s }
