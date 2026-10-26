package ports

import (
	"context"
)

type DriverProfile struct {
	UserID                 string
	FullName               string
	ServiceAreaID          string
	VerificationStatus     string
	VerificationReviewedBy *string
	VerificationReviewedAt *string
	VerificationNote       *string
	SuspensionReason       *string
	IsOnline               bool
	LastLocationLat        *float64
	LastLocationLon        *float64
	LastLocationAt         *string
	LastLocationAccuracyM  *float64
	RatingAvg              *float64
	RatingCount            int
	Status                 string
	CreatedAt              string
	UpdatedAt              string
}

type DriverRepository interface {
	FindByUserID(ctx context.Context, userID string) (DriverProfile, bool, error)
	SetOnline(ctx context.Context, userID string, isOnline bool) (DriverProfile, error)
	List(ctx context.Context, serviceAreaID *string, limit int, offset int) ([]DriverProfile, error)
}

var ErrDriverNotFound = driverNotFoundError{}

type driverNotFoundError struct{}

func (driverNotFoundError) Error() string        { return "driver profile not found" }
func (driverNotFoundError) Is(target error) bool { _, ok := target.(driverNotFoundError); return ok }

type Vehicle struct {
	ID            string
	DriverID      string
	VehicleTypeID string
	PlateNumber   string
	Make          *string
	Model         *string
	Year          *int
	Color         *string
	IsActive      bool
	CreatedAt     string
	UpdatedAt     string
}

type VehicleRepository interface {
	Create(ctx context.Context, vehicle Vehicle) (Vehicle, error)
	ListForDriver(ctx context.Context, driverID string) ([]Vehicle, error)
}

var ErrVehicleNotFound = vehicleNotFoundError{}

type vehicleNotFoundError struct{}

func (vehicleNotFoundError) Error() string        { return "vehicle not found" }
func (vehicleNotFoundError) Is(target error) bool { _, ok := target.(vehicleNotFoundError); return ok }

type CustomerProfile struct {
	UserID    string
	CreatedAt string
}

type CustomerRepository interface {
	GetOrCreate(ctx context.Context, userID string) (CustomerProfile, error)
}

type SavedPlace struct {
	ID          string
	CustomerID  string
	Label       string
	AddressText *string
	LocationLat float64
	LocationLon float64
	CreatedAt   string
}

type SavedPlaceRepository interface {
	List(ctx context.Context, customerID string) ([]SavedPlace, error)
	Create(ctx context.Context, place SavedPlace) (SavedPlace, error)
}
