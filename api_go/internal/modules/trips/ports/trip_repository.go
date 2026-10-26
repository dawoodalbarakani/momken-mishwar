package ports

import (
	"context"

	ridesports "github.com/barakanid96/momken-mishwar/api_go/internal/modules/rides/ports"
)

// TripRepository extends the ride repository with trip-specific operations.
type TripRepository interface {
	ridesports.RideRepository
	// LockAndFind finds a ride and locks it for update.
	LockAndFind(ctx context.Context, id string) (ridesports.Ride, error)
	// UpdateRideFields updates arbitrary fields on a ride with optimistic concurrency.
	UpdateRideFields(ctx context.Context, id string, version int, updates map[string]interface{}) (ridesports.Ride, error)
}

var ErrTripNotFound = ridesports.ErrRideNotFound
var ErrTripConflict = ridesports.ErrRideConflict
