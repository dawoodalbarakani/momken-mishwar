package ports

import (
	"context"

	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/pricing"
	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/ride_state"
)

// Ride is a domain-level ride representation.
type Ride struct {
	ID                    string
	RideNumber            int64
	CustomerID            string
	DriverID              *string
	VehicleID             *string
	ServiceAreaID         string
	VehicleTypeID         string
	Status                ride_state.RideStatus
	PickupLat             float64
	PickupLon             float64
	PickupAddress         *string
	DestinationLat        float64
	DestinationLon        float64
	DestinationAddress    *string
	PaymentMethod         string
	CurrencyCode          string
	PricingRuleID         string
	PricingRuleVersion    int
	PriceBreakdown        pricing.PriceBreakdown
	QuotedTotalMinor      int64
	FinalTotalMinor       *int64
	CommissionAmountMinor *int64
	DriverNetMinor        *int64
	EstimatedDistanceM    int64
	EstimatedDurationS    int64
	ActualDistanceM       *int64
	ActualDurationS       *int64
	SearchExpiresAt       *string
	StartCodeNonce        []byte
	StartCodeExpiresAt    *string
	StartCodeAttempts     int
	CancelledByRole       *string
	CancelledByUserID     *string
	CancelReasonCode      *string
	CancelNote            *string
	RequestedAt           string
	AssignedAt            *string
	ArrivedAt             *string
	StartedAt             *string
	CompletedAt           *string
	CancelledAt           *string
	Version               int
	CreatedAt             string
	UpdatedAt             string
}

// RideRepository is the persistence port for rides.
type RideRepository interface {
	Create(ctx context.Context, ride Ride) (Ride, error)
	FindByID(ctx context.Context, id string) (Ride, error)
	FindActiveByCustomer(ctx context.Context, customerID string) (Ride, bool, error)
	UpdateStatus(ctx context.Context, id string, status ride_state.RideStatus, version int, updates map[string]interface{}) (Ride, error)
	CreateEvent(ctx context.Context, rideID, eventType, fromStatus, toStatus, actorRole, actorUserID *string, payload string) error
	List(ctx context.Context, status *ride_state.RideStatus, limit int, offset int) ([]Ride, error)
	// FindRideForUpdate locks a ride row FOR UPDATE within a transaction.
	FindRideForUpdate(ctx context.Context, id string) (Ride, error)
}

var (
	ErrRideNotFound = rideNotFoundError{}
	ErrRideConflict = rideConflictError{}
)

type rideNotFoundError struct{}
type rideConflictError struct{}

func (rideNotFoundError) Error() string        { return "ride not found" }
func (rideConflictError) Error() string        { return "ride conflict: concurrent modification" }
func (rideNotFoundError) Is(target error) bool { _, ok := target.(rideNotFoundError); return ok }
func (rideConflictError) Is(target error) bool { _, ok := target.(rideConflictError); return ok }
