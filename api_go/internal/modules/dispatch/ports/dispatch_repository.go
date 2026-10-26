package ports

import (
	"context"
)

type RideOffer struct {
	ID                 string
	RideID             string
	DriverID           string
	Status             string
	RoundNo            int
	DistanceToPickupM  *int64
	ETASecondsEstimate *int64
	DriverLocationAgeS *int64
	OfferedAt          string
	ExpiresAt          string
	RespondedAt        *string
}

type RideOfferRepository interface {
	FindPendingByRide(ctx context.Context, rideID string) ([]RideOffer, error)
	FindByIDAndDriver(ctx context.Context, offerID, driverID string) (RideOffer, error)
	Create(ctx context.Context, offer RideOffer) (RideOffer, error)
	UpdateStatus(ctx context.Context, offerID string, status string) (RideOffer, error)
	UpdateManyStatus(ctx context.Context, rideID string, excludeOfferID string, status string) error
	MarkExpired(ctx context.Context) error
}

var ErrOfferNotFound = offerNotFoundError{}
var ErrOfferConflict = offerConflictError{}

type offerNotFoundError struct{}
type offerConflictError struct{}

func (offerNotFoundError) Error() string        { return "ride offer not found" }
func (offerConflictError) Error() string        { return "ride offer conflict" }
func (offerNotFoundError) Is(target error) bool { _, ok := target.(offerNotFoundError); return ok }
func (offerConflictError) Is(target error) bool { _, ok := target.(offerConflictError); return ok }

type DispatchSettings struct {
	ServiceAreaID         string
	SearchRadiusM         int
	MaxCandidates         int
	OfferBatchSize        int
	OfferTTLSeconds       int
	SearchTimeoutSeconds  int
	LocationMaxAgeSeconds int
	StartCodeTTLMinutes   int
	StartCodeMaxAttempts  int
}

type DispatchSettingsRepository interface {
	FindByServiceArea(ctx context.Context, serviceAreaID string) (DispatchSettings, bool, error)
}

type DriverRepository interface {
	FindOnlineApprovedInArea(ctx context.Context, serviceAreaID string, maxAgeSeconds int, radiusM int, pickupLat, pickupLon float64, limit int) ([]DriverCandidate, error)
	HasActiveRide(ctx context.Context, driverID string) (bool, error)
	FindProfile(ctx context.Context, driverID string) (DriverProfile, error)
}

type DriverCandidate struct {
	DriverID  string
	DistanceM float64
}

type DriverProfile struct {
	UserID             string
	VerificationStatus string
	IsOnline           bool
	ServiceAreaID      string
	Status             string
}

type VehicleRepository interface {
	FindActiveByDriverAndType(ctx context.Context, vehicleID, driverID, vehicleTypeID string) (bool, error)
}
