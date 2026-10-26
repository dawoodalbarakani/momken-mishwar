package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	pgxpool "github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/pricing"
	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/ride_state"
	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/start_code"
	idemports "github.com/barakanid96/momken-mishwar/api_go/internal/modules/idempotency/ports"
	ridesports "github.com/barakanid96/momken-mishwar/api_go/internal/modules/rides/ports"
)

var (
	ErrRideServiceConfig = errors.New("ride service is not configured")
	ErrRideNotFound      = errors.New("ride not found")
	ErrRideConflict      = errors.New("ride conflict")
	ErrAlreadyActive     = errors.New("customer already has an active ride")
	ErrInvalidRideInput  = errors.New("invalid ride input")
)

// PricingClient computes fare quotes.
type PricingClient interface {
	Quote(ctx context.Context, serviceAreaID, vehicleTypeID string, pickupLat, pickupLon, destLat, destLon float64) (pricing.PriceBreakdown, int64, int64, error)
}

// RideService orchestrates ride requests and lifecycle transitions.
type RideService struct {
	db              *pgxpool.Pool
	repo            ridesports.RideRepository
	idempotency     idemports.IdempotencyStore
	pricingClient   PricingClient
	startCodeSecret []byte
	now             func() time.Time
}

type RideServiceConfig struct {
	DB              *pgxpool.Pool
	Repo            ridesports.RideRepository
	Idempotency     idemports.IdempotencyStore
	Pricing         PricingClient
	StartCodeSecret []byte
	Now             func() time.Time
}

func NewRideService(cfg RideServiceConfig) (*RideService, error) {
	if cfg.DB == nil || cfg.Repo == nil || cfg.Idempotency == nil || cfg.Pricing == nil {
		return nil, ErrRideServiceConfig
	}
	if len(cfg.StartCodeSecret) < 32 {
		return nil, errors.New("start code secret must be at least 32 bytes")
	}
	if cfg.Now == nil {
		cfg.Now = time.Now
	}
	return &RideService{
		db:              cfg.DB,
		repo:            cfg.Repo,
		idempotency:     cfg.Idempotency,
		pricingClient:   cfg.Pricing,
		startCodeSecret: append([]byte(nil), cfg.StartCodeSecret...),
		now:             cfg.Now,
	}, nil
}

// CreateRideRequest creates a new SEARCHING ride with a server-computed price.
func (s *RideService) CreateRideRequest(ctx context.Context, params CreateRideParams) (*CreateRideResult, error) {
	if params.CustomerID == "" || params.ServiceAreaID == "" || params.VehicleTypeID == "" {
		return nil, ErrInvalidRideInput
	}
	if params.IdempotencyKey == "" {
		return nil, ErrInvalidRideInput
	}

	requestHash := hashRequest(params.ServiceAreaID, params.VehicleTypeID, params.PickupLat, params.PickupLon, params.DestLat, params.DestLon)

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var customerID string
	err = tx.QueryRow(ctx, "SELECT id FROM users WHERE id = $1::uuid FOR UPDATE", params.CustomerID).Scan(&customerID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("customer not found: %w", ErrRideNotFound)
	}
	if err != nil {
		return nil, fmt.Errorf("load customer: %w", err)
	}

	body, replayed, err := s.idempotency.Check(ctx, params.CustomerID, "POST /rides", params.IdempotencyKey, requestHash)
	if err != nil {
		return nil, fmt.Errorf("check idempotency: %w", err)
	}
	if replayed {
		var result CreateRideResult
		if err := json.Unmarshal(body, &result); err != nil {
			return nil, fmt.Errorf("replay idempotent response: %w", err)
		}
		result.Replayed = true
		return &result, nil
	}

	active, found, err := s.repo.FindActiveByCustomer(ctx, params.CustomerID)
	if err != nil {
		return nil, fmt.Errorf("check active ride: %w", err)
	}
	_ = active
	if found {
		return nil, ErrAlreadyActive
	}

	breakdown, distanceM, durationS, err := s.pricingClient.Quote(ctx, params.ServiceAreaID, params.VehicleTypeID, params.PickupLat, params.PickupLon, params.DestLat, params.DestLon)
	if err != nil {
		return nil, fmt.Errorf("compute fare: %w", err)
	}

	ride, err := s.repo.Create(ctx, ridesports.Ride{
		CustomerID:         params.CustomerID,
		ServiceAreaID:      params.ServiceAreaID,
		VehicleTypeID:      params.VehicleTypeID,
		Status:             ride_state.StatusSearching,
		PickupLat:          params.PickupLat,
		PickupLon:          params.PickupLon,
		DestinationLat:     params.DestLat,
		DestinationLon:     params.DestLon,
		PaymentMethod:      "CASH",
		CurrencyCode:       breakdown.Currency,
		PricingRuleID:      breakdown.RuleID,
		PricingRuleVersion: breakdown.RuleVersion,
		PriceBreakdown:     breakdown,
		QuotedTotalMinor:   breakdown.TotalMinor,
		EstimatedDistanceM: distanceM,
		EstimatedDurationS: durationS,
	})
	if err != nil {
		return nil, fmt.Errorf("create ride: %w", err)
	}

	expiresAt := s.now().UTC().Add(24 * time.Hour)
	if err := s.idempotency.Record(ctx, params.CustomerID, "POST /rides", params.IdempotencyKey, requestHash, 201, nil, &ride.ID, expiresAt); err != nil {
		return nil, fmt.Errorf("record idempotency: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit ride creation: %w", err)
	}

	return &CreateRideResult{
		Ride:     ride,
		Replayed: false,
	}, nil
}

// CancelRide cancels a ride owned by the customer.
func (s *RideService) CancelRide(ctx context.Context, rideID, customerID, reasonCode, note string) (*CancelRideResult, error) {
	if rideID == "" || customerID == "" || reasonCode == "" {
		return nil, ErrInvalidRideInput
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	ride, err := s.repo.FindByID(ctx, rideID)
	if err != nil {
		if errors.Is(err, ridesports.ErrRideNotFound) {
			return nil, ErrRideNotFound
		}
		return nil, fmt.Errorf("find ride: %w", err)
	}
	if ride.CustomerID != customerID {
		return nil, errors.New("not your ride")
	}

	snapshot := ride_state.RideSnapshot{
		Status:     ride.Status,
		CustomerID: ride.CustomerID,
		DriverID:   ride.DriverID,
	}
	actor := ride_state.Actor{Role: ride_state.ActorCustomer, UserID: customerID}
	result, err := ride_state.Transition(snapshot, ride_state.EventCancel, actor, ride_state.TransitionContext{
		CancelReasonCode: reasonCode,
	})
	if err != nil {
		return nil, err
	}

	now := s.now().UTC()
	updates := map[string]interface{}{
		"cancelled_by_role":    strPtr(string(*result.CancelledBy)),
		"cancelled_by_user_id": customerID,
		"cancel_reason_code":   result.CancelReasonCode,
		"cancel_note":          note,
		"cancelled_at":         now,
	}
	updated, err := s.repo.UpdateStatus(ctx, rideID, result.To, ride.Version, updates)
	if err != nil {
		if errors.Is(err, ridesports.ErrRideConflict) {
			return nil, ErrRideConflict
		}
		if errors.Is(err, ridesports.ErrRideNotFound) {
			return nil, ErrRideNotFound
		}
		return nil, fmt.Errorf("update ride status: %w", err)
	}

	if err := s.repo.CreateEvent(ctx, strPtr(rideID), strPtr(string(ride_state.EventCancel)), strPtr(string(ride.Status)), strPtr(string(result.To)), strPtr(string(ride_state.ActorCustomer)), strPtr(customerID), "{}"); err != nil {
		return nil, fmt.Errorf("create ride event: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit ride cancellation: %w", err)
	}

	return &CancelRideResult{
		Ride:       updated,
		Transition: result,
	}, nil
}

// GetRide returns a ride by ID.
func (s *RideService) GetRide(ctx context.Context, id string) (*ridesports.Ride, error) {
	ride, err := s.repo.FindByID(ctx, id)
	if err != nil {
		if errors.Is(err, ridesports.ErrRideNotFound) {
			return nil, ErrRideNotFound
		}
		return nil, fmt.Errorf("find ride: %w", err)
	}
	return &ride, nil
}

// GetActiveRide returns the customer's active ride, if any.
func (s *RideService) GetActiveRide(ctx context.Context, customerID string) (*ridesports.Ride, bool, error) {
	ride, found, err := s.repo.FindActiveByCustomer(ctx, customerID)
	if err != nil {
		return nil, false, fmt.Errorf("find active ride: %w", err)
	}
	if !found {
		return nil, false, nil
	}
	return &ride, true, nil
}

func hashRequest(serviceAreaID, vehicleTypeID string, pickupLat, pickupLon, destLat, destLon float64) string {
	h := sha256.New()
	_, _ = h.Write([]byte(serviceAreaID))
	_, _ = h.Write([]byte{0})
	_, _ = h.Write([]byte(vehicleTypeID))
	_, _ = h.Write([]byte{0})
	_, _ = fmt.Fprintf(h, "%f", pickupLat)
	_, _ = h.Write([]byte{0})
	_, _ = fmt.Fprintf(h, "%f", pickupLon)
	_, _ = h.Write([]byte{0})
	_, _ = fmt.Fprintf(h, "%f", destLat)
	_, _ = h.Write([]byte{0})
	_, _ = fmt.Fprintf(h, "%f", destLon)
	return hex.EncodeToString(h.Sum(nil))
}

func strPtr(s string) *string { return &s }

var _ = start_code.DeriveStartCode

// CreateRideParams are the inputs to create a ride.
type CreateRideParams struct {
	CustomerID     string
	ServiceAreaID  string
	VehicleTypeID  string
	PickupLat      float64
	PickupLon      float64
	DestLat        float64
	DestLon        float64
	IdempotencyKey string
}

// CreateRideResult is the outcome of creating a ride.
type CreateRideResult struct {
	Ride     ridesports.Ride
	Replayed bool
}

// CancelRideResult is the outcome of cancelling a ride.
type CancelRideResult struct {
	Ride       ridesports.Ride
	Transition ride_state.TransitionResult
}
