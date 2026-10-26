package postgres

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/ride_state"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/rides/ports"
)

type RideRepository struct {
	db *pgxpool.Pool
}

func NewRideRepository(db *pgxpool.Pool) *RideRepository {
	return &RideRepository{db: db}
}

const (
	rideColumns = `
		id::text, ride_number, customer_id::text, driver_id::text, vehicle_id::text,
		service_area_id::text, vehicle_type_id::text, status,
		ST_X(pickup::geometry), ST_Y(pickup::geometry), pickup_address,
		ST_X(destination::geometry), ST_Y(destination::geometry), destination_address,
		payment_method, currency_code, pricing_rule_id::text, pricing_rule_version,
		price_breakdown, quoted_total, final_total, commission_amount, driver_net,
		estimated_distance_m, estimated_duration_s, actual_distance_m, actual_duration_s,
		search_expires_at, start_code_nonce, start_code_expires_at, start_code_attempts,
		cancelled_by_role, cancelled_by_user_id::text,
		cancel_reason_code, cancel_note,
		requested_at, assigned_at, arrived_at, started_at, completed_at, cancelled_at,
		version, created_at, updated_at`
)

func (r *RideRepository) Create(ctx context.Context, ride ports.Ride) (ports.Ride, error) {
	if r.db == nil {
		return ports.Ride{}, errors.New("rides repository: nil database")
	}
	pb, err := json.Marshal(ride.PriceBreakdown)
	if err != nil {
		return ports.Ride{}, fmt.Errorf("marshal price breakdown: %w", err)
	}

	row := r.db.QueryRow(ctx, `
		INSERT INTO rides (
			customer_id, service_area_id, vehicle_type_id, status, pickup, destination,
			pickup_address, destination_address, payment_method, currency_code,
			pricing_rule_id, pricing_rule_version, price_breakdown, quoted_total,
			estimated_distance_m, estimated_duration_s, search_expires_at
		) VALUES (
			$1::uuid, $2::uuid, $3::uuid, 'SEARCHING',
			ST_SetSRID(ST_MakePoint($4, $5)::geometry, 4326)::geography,
			ST_SetSRID(ST_MakePoint($6, $7)::geometry, 4326)::geography,
			$8, $9, 'CASH', $10, $11::uuid, $12, $13::jsonb, $14,
			$15, $16, now() + interval '5 minutes'
		) RETURNING `+rideColumns,
		ride.CustomerID, ride.ServiceAreaID, ride.VehicleTypeID,
		ride.PickupLon, ride.PickupLat, ride.DestinationLon, ride.DestinationLat,
		nullStr(ride.PickupAddress), nullStr(ride.DestinationAddress), ride.CurrencyCode,
		ride.PricingRuleID, ride.PricingRuleVersion, string(pb), ride.QuotedTotalMinor,
		ride.EstimatedDistanceM, ride.EstimatedDurationS,
	)

	return scanRideFromRow(row)
}

func (r *RideRepository) FindByID(ctx context.Context, id string) (ports.Ride, error) {
	if r.db == nil {
		return ports.Ride{}, errors.New("rides repository: nil database")
	}
	row := r.db.QueryRow(ctx, "SELECT "+rideColumns+" FROM rides WHERE id = $1::uuid", id)
	return scanRideFromRow(row)
}

func (r *RideRepository) FindActiveByCustomer(ctx context.Context, customerID string) (ports.Ride, bool, error) {
	if r.db == nil {
		return ports.Ride{}, false, errors.New("rides repository: nil database")
	}
	row := r.db.QueryRow(ctx, `
		SELECT `+rideColumns+`
		FROM rides
		WHERE customer_id = $1::uuid
		  AND status IN ('SEARCHING','ASSIGNED','ARRIVING','ARRIVED','IN_PROGRESS')
		ORDER BY requested_at DESC
		LIMIT 1`, customerID)
	ride, err := scanRideFromRow(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return ports.Ride{}, false, nil
	}
	if err != nil {
		return ports.Ride{}, false, fmt.Errorf("query active ride: %w", err)
	}
	return ride, true, nil
}

func (r *RideRepository) UpdateStatus(ctx context.Context, id string, status ride_state.RideStatus, version int, updates map[string]interface{}) (ports.Ride, error) {
	if r.db == nil {
		return ports.Ride{}, errors.New("rides repository: nil database")
	}
	setParts := []string{"status = $2", "version = version + 1"}
	args := []interface{}{id, string(status)}
	argIdx := 3
	for col, val := range updates {
		setParts = append(setParts, col+" = $"+argNum(argIdx))
		args = append(args, val)
		argIdx++
	}
	query := "UPDATE rides SET " + strings.Join(setParts, ", ") +
		" WHERE id = $1 AND version = $" + argNum(argIdx) +
		" RETURNING " + rideColumns
	args = append(args, version)

	row := r.db.QueryRow(ctx, query, args...)
	ride, err := scanRideFromRow(row)
	if errors.Is(err, pgx.ErrNoRows) {
		var exists bool
		err2 := r.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM rides WHERE id = $1::uuid)", id).Scan(&exists)
		if err2 != nil {
			return ports.Ride{}, fmt.Errorf("check ride existence: %w", err2)
		}
		if !exists {
			return ports.Ride{}, ports.ErrRideNotFound
		}
		return ports.Ride{}, ports.ErrRideConflict
	}
	if err != nil {
		return ports.Ride{}, fmt.Errorf("update ride status: %w", err)
	}
	return ride, nil
}

func (r *RideRepository) CreateEvent(ctx context.Context, rideID, eventType, fromStatus, toStatus, actorRole, actorUserID *string, payload string) error {
	if r.db == nil {
		return errors.New("rides repository: nil database")
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO ride_events (ride_id, event_type, from_status, to_status, actor_role, actor_user_id, payload)
		VALUES ($1::uuid, $2, $3, $4, $5, $6::uuid, $7::jsonb)`,
		rideID, eventType, fromStatus, toStatus, actorRole, actorUserID, payload)
	if err != nil {
		return fmt.Errorf("create ride event: %w", err)
	}
	return nil
}

func (r *RideRepository) List(ctx context.Context, status *ride_state.RideStatus, limit int, offset int) ([]ports.Ride, error) {
	if r.db == nil {
		return nil, errors.New("rides repository: nil database")
	}
	query := "SELECT " + rideColumns + " FROM rides"
	args := []interface{}{}
	argIdx := 1
	if status != nil {
		query += " WHERE status = $" + argNum(argIdx)
		args = append(args, string(*status))
		argIdx++
	}
	query += " ORDER BY requested_at DESC LIMIT $" + argNum(argIdx)
	args = append(args, limit)
	argIdx++
	query += " OFFSET $" + argNum(argIdx)
	args = append(args, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list rides: %w", err)
	}
	defer rows.Close()

	var rides []ports.Ride
	for rows.Next() {
		ride, err := scanRideFromRow(rows)
		if err != nil {
			return nil, fmt.Errorf("scan ride: %w", err)
		}
		rides = append(rides, ride)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate rides: %w", err)
	}
	return rides, nil
}

func (r *RideRepository) FindRideForUpdate(ctx context.Context, id string) (ports.Ride, error) {
	if r.db == nil {
		return ports.Ride{}, errors.New("rides repository: nil database")
	}
	row := r.db.QueryRow(ctx, "SELECT "+rideColumns+" FROM rides WHERE id = $1::uuid FOR UPDATE", id)
	return scanRideFromRow(row)
}

// scanRideFromRow scans any scanner (pgx.Row or pgx.Rows) into a Ride.
func scanRideFromRow(scanner interface {
	Scan(...interface{}) error
}) (ports.Ride, error) {
	var ride ports.Ride
	var driverID, vehicleID sql.NullString
	var pickupAddr, destAddr sql.NullString
	var finalTotal, commissionAmount, driverNet sql.NullFloat64
	var actualDistanceM, actualDurationS sql.NullInt64
	var searchExpiresAt, startCodeExpiresAt sql.NullTime
	var startCodeNonce []byte
	var startCodeAttempts int
	var cancelledByRole, cancelledByUserID sql.NullString
	var cancelReasonCode, cancelNote sql.NullString
	var requestedAt, assignedAt, arrivedAt, startedAt, completedAt, cancelledAt sql.NullTime
	var createdAt, updatedAt sql.NullTime
	var priceBreakdown []byte
	var status string

	err := scanner.Scan(
		&ride.ID, &ride.RideNumber, &ride.CustomerID, &driverID, &vehicleID,
		&ride.ServiceAreaID, &ride.VehicleTypeID, &status,
		&ride.PickupLon, &ride.PickupLat, &pickupAddr,
		&ride.DestinationLon, &ride.DestinationLat, &destAddr,
		&ride.PaymentMethod, &ride.CurrencyCode, &ride.PricingRuleID, &ride.PricingRuleVersion,
		&priceBreakdown, &ride.QuotedTotalMinor, &finalTotal, &commissionAmount, &driverNet,
		&ride.EstimatedDistanceM, &ride.EstimatedDurationS, &actualDistanceM, &actualDurationS,
		&searchExpiresAt, &startCodeNonce, &startCodeExpiresAt, &startCodeAttempts,
		&cancelledByRole, &cancelledByUserID,
		&cancelReasonCode, &cancelNote,
		&requestedAt, &assignedAt, &arrivedAt, &startedAt, &completedAt, &cancelledAt,
		&ride.Version, &createdAt, &updatedAt,
	)
	if err != nil {
		return ports.Ride{}, err
	}

	ride.Status = ride_state.RideStatus(status)
	ride.DriverID = nullStrPtr(driverID)
	ride.VehicleID = nullStrPtr(vehicleID)
	ride.PickupAddress = nullStrPtr(pickupAddr)
	ride.DestinationAddress = nullStrPtr(destAddr)
	if err := json.Unmarshal(priceBreakdown, &ride.PriceBreakdown); err != nil {
		return ports.Ride{}, fmt.Errorf("unmarshal price breakdown: %w", err)
	}
	ride.FinalTotalMinor = nullFloat64Ptr(finalTotal, roundToMinor)
	ride.CommissionAmountMinor = nullFloat64Ptr(commissionAmount, roundToMinor)
	ride.DriverNetMinor = nullFloat64Ptr(driverNet, roundToMinor)
	ride.ActualDistanceM = nullInt64Ptr(actualDistanceM)
	ride.ActualDurationS = nullInt64Ptr(actualDurationS)
	ride.SearchExpiresAt = nullTimeStrPtr(searchExpiresAt)
	ride.StartCodeNonce = startCodeNonce
	if startCodeExpiresAt.Valid {
		s := startCodeExpiresAt.Time.UTC().Format(time.RFC3339Nano)
		ride.StartCodeExpiresAt = &s
	}
	ride.StartCodeAttempts = startCodeAttempts
	ride.CancelledByRole = nullStrPtr(cancelledByRole)
	ride.CancelledByUserID = nullStrPtr(cancelledByUserID)
	ride.CancelReasonCode = nullStrPtr(cancelReasonCode)
	ride.CancelNote = nullStrPtr(cancelNote)
	ride.RequestedAt = nullTimeStr(requestedAt)
	ride.AssignedAt = nullTimeStrPtr(assignedAt)
	ride.ArrivedAt = nullTimeStrPtr(arrivedAt)
	ride.StartedAt = nullTimeStrPtr(startedAt)
	ride.CompletedAt = nullTimeStrPtr(completedAt)
	ride.CancelledAt = nullTimeStrPtr(cancelledAt)
	ride.CreatedAt = nullTimeStr(createdAt)
	ride.UpdatedAt = nullTimeStr(updatedAt)
	return ride, nil
}

func argNum(n int) string { return fmt.Sprintf("$%d", n) }

func nullStr(s *string) *string {
	if s == nil {
		return nil
	}
	return s
}

func nullStrPtr(ns sql.NullString) *string {
	if !ns.Valid {
		return nil
	}
	return &ns.String
}

func nullFloat64Ptr(ns sql.NullFloat64, conv func(float64) int64) *int64 {
	if !ns.Valid {
		return nil
	}
	v := conv(ns.Float64)
	return &v
}

func nullInt64Ptr(ns sql.NullInt64) *int64 {
	if !ns.Valid {
		return nil
	}
	return &ns.Int64
}

func nullTimeStr(nt sql.NullTime) string {
	if !nt.Valid {
		return ""
	}
	return nt.Time.UTC().Format(time.RFC3339Nano)
}

func nullTimeStrPtr(nt sql.NullTime) *string {
	if !nt.Valid {
		return nil
	}
	s := nt.Time.UTC().Format(time.RFC3339Nano)
	return &s
}

func roundToMinor(f float64) int64 {
	if f < 0 {
		return int64(f - 0.5)
	}
	return int64(f + 0.5)
}
