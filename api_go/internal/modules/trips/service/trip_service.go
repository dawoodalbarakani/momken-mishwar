package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	pgxpool "github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/ride_state"
	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/start_code"
	ridesports "github.com/barakanid96/momken-mishwar/api_go/internal/modules/rides/ports"
)

var (
	ErrTripServiceConfig = errors.New("trip service is not configured")
	ErrTripNotFound      = errors.New("trip not found")
	ErrTripConflict      = errors.New("trip conflict")
	ErrNotYourRide       = errors.New("not your ride")
	ErrStartCodeRequired = errors.New("start code is required")
)

type TripService struct {
	db              *pgxpool.Pool
	repo            ridesports.RideRepository
	ledgerClient    LedgerClient
	startCodeSecret []byte
	now             func() time.Time
}

type LedgerClient interface {
	SettleCashRide(ctx context.Context, rideID, driverID, currency string, grossMinor, commissionMinor, driverNetMinor int64, idempotencyKey string) error
}

type TripServiceConfig struct {
	DB              *pgxpool.Pool
	Repo            ridesports.RideRepository
	LedgerClient    LedgerClient
	StartCodeSecret []byte
	Now             func() time.Time
}

func NewTripService(cfg TripServiceConfig) (*TripService, error) {
	if cfg.DB == nil || cfg.Repo == nil || cfg.LedgerClient == nil {
		return nil, ErrTripServiceConfig
	}
	if len(cfg.StartCodeSecret) < 32 {
		return nil, errors.New("start code secret must be at least 32 bytes")
	}
	if cfg.Now == nil {
		cfg.Now = time.Now
	}
	return &TripService{
		db:              cfg.DB,
		repo:            cfg.Repo,
		ledgerClient:    cfg.LedgerClient,
		startCodeSecret: append([]byte(nil), cfg.StartCodeSecret...),
		now:             cfg.Now,
	}, nil
}

type TripAction struct {
	RideID   string
	DriverID string
	Code     string // for start action
}

func (s *TripService) EnRoute(ctx context.Context, rideID, driverID string) (*ridesports.Ride, error) {
	return s.transition(ctx, rideID, driverID, ride_state.EventDriverEnRoute, nil)
}

func (s *TripService) Arrived(ctx context.Context, rideID, driverID string) (*ridesports.Ride, error) {
	return s.transition(ctx, rideID, driverID, ride_state.EventDriverArrived, nil)
}

func (s *TripService) StartTrip(ctx context.Context, rideID, driverID, code string) (*ridesports.Ride, error) {
	if code == "" {
		return nil, ErrStartCodeRequired
	}
	return s.transition(ctx, rideID, driverID, ride_state.EventTripStarted, &code)
}

func (s *TripService) CompleteTrip(ctx context.Context, rideID, driverID string) (*ridesports.Ride, error) {
	return s.transition(ctx, rideID, driverID, ride_state.EventTripCompleted, nil)
}

func (s *TripService) GetStartCode(ctx context.Context, rideID, customerID string) (string, string, error) {
	ride, err := s.repo.FindByID(ctx, rideID)
	if err != nil {
		if errors.Is(err, ridesports.ErrRideNotFound) {
			return "", "", ErrTripNotFound
		}
		return "", "", fmt.Errorf("find ride: %w", err)
	}
	if ride.CustomerID != customerID {
		return "", "", ErrNotYourRide
	}

	now := s.now().UTC()
	var nonce []byte
	var expiresAt time.Time

	if ride.StartCodeNonce == nil || ride.StartCodeExpiresAt == nil {
		// Generate a fresh nonce
		nonce, err = start_code.NewNonce()
		if err != nil {
			return "", "", fmt.Errorf("generate nonce: %w", err)
		}
		expiresAt = now.Add(15 * time.Minute)
		// Update the ride with the new nonce
		_, err = s.repo.UpdateStatus(ctx, rideID, ride.Status, ride.Version, map[string]interface{}{
			"start_code_nonce":      nonce,
			"start_code_expires_at": expiresAt,
			"start_code_attempts":   0,
		})
		if err != nil {
			return "", "", fmt.Errorf("update ride start code: %w", err)
		}
	} else {
		nonce = ride.StartCodeNonce
		expiresAt, _ = time.Parse(time.RFC3339Nano, *ride.StartCodeExpiresAt)
	}

	code, err := start_code.DeriveStartCode(s.startCodeSecret, rideID, nonce, start_code.StartCodeDigits)
	if err != nil {
		return "", "", fmt.Errorf("derive start code: %w", err)
	}

	return code, expiresAt.Format(time.RFC3339Nano), nil
}

func (s *TripService) transition(ctx context.Context, rideID, driverID string, event ride_state.RideEvent, code *string) (*ridesports.Ride, error) {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	ride, err := s.repo.FindByID(ctx, rideID)
	if err != nil {
		if errors.Is(err, ridesports.ErrRideNotFound) {
			return nil, ErrTripNotFound
		}
		return nil, fmt.Errorf("find ride: %w", err)
	}
	if ride.DriverID == nil || *ride.DriverID != driverID {
		return nil, ErrNotYourRide
	}

	snapshot := ride_state.RideSnapshot{
		Status:     ride.Status,
		CustomerID: ride.CustomerID,
		DriverID:   ride.DriverID,
	}
	actor := ride_state.Actor{Role: ride_state.ActorDriver, UserID: driverID}

	ctxTransition := ride_state.TransitionContext{}
	if event == ride_state.EventTripStarted {
		if code == nil {
			return nil, ErrStartCodeRequired
		}
		// Verify start code
		if ride.StartCodeNonce == nil || ride.StartCodeExpiresAt == nil {
			return nil, errors.New("no start code for this ride")
		}
		// Increment attempts atomically
		var attempts int
		err = tx.QueryRow(ctx, `
			UPDATE rides SET start_code_attempts = start_code_attempts + 1
			WHERE id = $1::uuid
			RETURNING start_code_attempts`, rideID).Scan(&attempts)
		if err != nil {
			return nil, fmt.Errorf("increment start code attempts: %w", err)
		}
		result := start_code.VerifyStartCode(start_code.VerifyStartCodeInput{
			Secret:       s.startCodeSecret,
			RideID:       rideID,
			Nonce:        ride.StartCodeNonce,
			Submitted:    *code,
			ExpiresAt:    func() time.Time { t, _ := time.Parse(time.RFC3339Nano, *ride.StartCodeExpiresAt); return t }(),
			Now:          s.now().UTC(),
			AttemptsUsed: attempts,
			MaxAttempts:  5,
			Digits:       start_code.StartCodeDigits,
		})
		if !result.OK {
			return nil, fmt.Errorf("start code verification failed: %s", result.Reason)
		}
		ctxTransition.StartCodeVerified = true
	}

	result, err := ride_state.Transition(snapshot, event, actor, ctxTransition)
	if err != nil {
		return nil, err
	}

	now := s.now().UTC()
	updates := map[string]interface{}{}
	switch result.To {
	case ride_state.StatusArriving:
		updates = map[string]interface{}{}
	case ride_state.StatusArrived:
		updates = map[string]interface{}{}
	case ride_state.StatusInProgress:
		updates = map[string]interface{}{
			"started_at": now,
		}
	case ride_state.StatusCompleted:
		updates = map[string]interface{}{
			"completed_at":      now,
			"final_total":       ride.QuotedTotalMinor,
			"commission_amount": ride.PriceBreakdown.CommissionMinor,
			"driver_net":        ride.PriceBreakdown.DriverNetMinor,
		}
	case ride_state.StatusCancelled:
		updates = map[string]interface{}{
			"cancelled_at":         now,
			"cancelled_by_role":    string(ride_state.ActorDriver),
			"cancelled_by_user_id": driverID,
			"cancel_reason_code":   result.CancelReasonCode,
		}
	}

	updated, err := s.repo.UpdateStatus(ctx, rideID, result.To, ride.Version, updates)
	if err != nil {
		if errors.Is(err, ridesports.ErrRideConflict) {
			return nil, ErrTripConflict
		}
		if errors.Is(err, ridesports.ErrRideNotFound) {
			return nil, ErrTripNotFound
		}
		return nil, fmt.Errorf("update ride status: %w", err)
	}

	if err := s.repo.CreateEvent(ctx, strPtr(rideID), strPtr(string(event)), strPtr(string(ride.Status)), strPtr(string(result.To)), strPtr(string(ride_state.ActorDriver)), strPtr(driverID), "{}"); err != nil {
		return nil, fmt.Errorf("create ride event: %w", err)
	}

	// On completion, create ledger entries
	if result.To == ride_state.StatusCompleted {
		idempotencyKey := "ride:" + rideID + ":SETTLEMENT"
		if err := s.ledgerClient.SettleCashRide(ctx, rideID, driverID, ride.CurrencyCode,
			ride.QuotedTotalMinor, ride.PriceBreakdown.CommissionMinor, ride.PriceBreakdown.DriverNetMinor,
			idempotencyKey); err != nil {
			return nil, fmt.Errorf("settle cash ride: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit transition: %w", err)
	}

	return &updated, nil
}

func strPtr(s string) *string { return &s }
