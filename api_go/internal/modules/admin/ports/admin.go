package ports

import (
	"context"
)

type AdminDriver struct {
	UserID             string
	PhoneE164          *string
	DisplayName        *string
	VerificationStatus string
	IsOnline           bool
	RatingAvg          *float64
	RatingCount        int
	CreatedAt          string
}

type AdminRide struct {
	ID               string
	RideNumber       int64
	CustomerID       string
	DriverID         *string
	Status           string
	QuotedTotalMinor int64
	CurrencyCode     string
	RequestedAt      string
	CreatedAt        string
}

type AdminPayout struct {
	ID           string
	DriverID     string
	Direction    string
	AmountMinor  int64
	CurrencyCode string
	Status       string
	RequestedBy  string
	ReviewedBy   *string
	CreatedAt    string
}

type AdminRepository interface {
	ListDrivers(ctx context.Context, status *string, limit int, offset int) ([]AdminDriver, error)
	ListRides(ctx context.Context, status *string, limit int, offset int) ([]AdminRide, error)
	CancelRide(ctx context.Context, rideID, reason, staffID string) error
	ListPricingRules(ctx context.Context, serviceAreaID *string) ([]PricingRule, error)
	ListPayouts(ctx context.Context, status *string, limit int, offset int) ([]AdminPayout, error)
	ApprovePayout(ctx context.Context, payoutID, reviewerID string) error
	DriverBalances(ctx context.Context) ([]DriverBalance, error)
	Stats(ctx context.Context) (*AdminStats, error)
}

type PricingRule struct {
	ID            string
	ServiceAreaID string
	VehicleTypeID string
	Version       int
	Mode          string
	CurrencyCode  string
	BaseFare      float64
	PerKm         float64
	PerMinute     float64
	MinimumFare   float64
	CommissionBps int
	RoundingStep  float64
	Status        string
	CreatedAt     string
}

type DriverBalance struct {
	DriverID     string
	CurrencyCode string
	Balance      float64
	EntryCount   int
	LastEntryAt  string
}

type AdminStats struct {
	TripsByStatus     map[string]int
	TotalRides        int
	OnlineDrivers     int
	TotalPaidOutMinor float64
}

var ErrAdminNotFound = adminNotFoundError{}

type adminNotFoundError struct{}

func (adminNotFoundError) Error() string        { return "not found" }
func (adminNotFoundError) Is(target error) bool { _, ok := target.(adminNotFoundError); return ok }
