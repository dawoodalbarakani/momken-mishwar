package postgres

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/dispatch/ports"
)

type RideOfferRepository struct {
	db *pgxpool.Pool
}

func NewRideOfferRepository(db *pgxpool.Pool) *RideOfferRepository {
	return &RideOfferRepository{db: db}
}

const offerColumns = `
	id::text, ride_id::text, driver_id::text, status, round_no,
	distance_to_pickup_m, eta_seconds_estimate, driver_location_age_s,
	offered_at, expires_at, responded_at`

func (r *RideOfferRepository) FindPendingByRide(ctx context.Context, rideID string) ([]ports.RideOffer, error) {
	if r.db == nil {
		return nil, errors.New("ride offer repository: nil database")
	}
	rows, err := r.db.Query(ctx, `
		SELECT `+offerColumns+`
		FROM ride_offers
		WHERE ride_id = $1::uuid AND status = 'PENDING' AND expires_at > now()
		ORDER BY offered_at ASC`, rideID)
	if err != nil {
		return nil, fmt.Errorf("query pending offers: %w", err)
	}
	defer rows.Close()
	return scanOffers(rows)
}

func (r *RideOfferRepository) FindByIDAndDriver(ctx context.Context, offerID, driverID string) (ports.RideOffer, error) {
	if r.db == nil {
		return ports.RideOffer{}, errors.New("ride offer repository: nil database")
	}
	row := r.db.QueryRow(ctx, `
		SELECT `+offerColumns+`
		FROM ride_offers
		WHERE id = $1::uuid AND driver_id = $2::uuid`, offerID, driverID)
	return scanOffer(row)
}

func (r *RideOfferRepository) Create(ctx context.Context, offer ports.RideOffer) (ports.RideOffer, error) {
	if r.db == nil {
		return ports.RideOffer{}, errors.New("ride offer repository: nil database")
	}
	row := r.db.QueryRow(ctx, `
		INSERT INTO ride_offers (ride_id, driver_id, status, round_no, distance_to_pickup_m, expires_at)
		VALUES ($1::uuid, $2::uuid, 'PENDING', $3, $4, $5::timestamptz)
		RETURNING `+offerColumns,
		offer.RideID, offer.DriverID, offer.RoundNo, offer.DistanceToPickupM, offer.ExpiresAt)
	return scanOffer(row)
}

func (r *RideOfferRepository) UpdateStatus(ctx context.Context, offerID string, status string) (ports.RideOffer, error) {
	if r.db == nil {
		return ports.RideOffer{}, errors.New("ride offer repository: nil database")
	}
	row := r.db.QueryRow(ctx, `
		UPDATE ride_offers SET status = $2, responded_at = now()
		WHERE id = $1::uuid
		RETURNING `+offerColumns, offerID, status)
	return scanOffer(row)
}

func (r *RideOfferRepository) UpdateManyStatus(ctx context.Context, rideID string, excludeOfferID string, status string) error {
	if r.db == nil {
		return errors.New("ride offer repository: nil database")
	}
	_, err := r.db.Exec(ctx, `
		UPDATE ride_offers SET status = $3, responded_at = now()
		WHERE ride_id = $1::uuid AND id <> $2::uuid AND status = 'PENDING'`,
		rideID, excludeOfferID, status)
	if err != nil {
		return fmt.Errorf("update many offers: %w", err)
	}
	return nil
}

func (r *RideOfferRepository) MarkExpired(ctx context.Context) error {
	if r.db == nil {
		return errors.New("ride offer repository: nil database")
	}
	_, err := r.db.Exec(ctx, `
		UPDATE ride_offers SET status = 'EXPIRED', responded_at = now()
		WHERE status = 'PENDING' AND expires_at < now()`)
	if err != nil {
		return fmt.Errorf("mark expired offers: %w", err)
	}
	return nil
}

func scanOffer(scanner interface {
	Scan(...interface{}) error
}) (ports.RideOffer, error) {
	var offer ports.RideOffer
	var distanceToPickupM, etaSeconds, driverLocationAge sql.NullInt64
	var respondedAt sql.NullString
	var offeredAt, expiresAt sql.NullTime

	err := scanner.Scan(
		&offer.ID, &offer.RideID, &offer.DriverID, &offer.Status, &offer.RoundNo,
		&distanceToPickupM, &etaSeconds, &driverLocationAge,
		&offeredAt, &expiresAt, &respondedAt,
	)
	if err != nil {
		return ports.RideOffer{}, err
	}
	offer.DistanceToPickupM = nullInt64Ptr(distanceToPickupM)
	offer.ETASecondsEstimate = nullInt64Ptr(etaSeconds)
	offer.DriverLocationAgeS = nullInt64Ptr(driverLocationAge)
	offer.OfferedAt = nullTimeStr(offeredAt)
	offer.ExpiresAt = nullTimeStr(expiresAt)
	if respondedAt.Valid {
		offer.RespondedAt = strPtr(respondedAt.String)
	}
	return offer, nil
}

func scanOffers(rows pgx.Rows) ([]ports.RideOffer, error) {
	var offers []ports.RideOffer
	for rows.Next() {
		offer, err := scanOffer(rows)
		if err != nil {
			return nil, err
		}
		offers = append(offers, offer)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return offers, nil
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

func strPtr(s string) *string { return &s }

var _ = json.Marshal
