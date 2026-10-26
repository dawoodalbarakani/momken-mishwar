package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	pgxpool "github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/ride_state"
	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/start_code"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/dispatch/ports"
	ridesports "github.com/barakanid96/momken-mishwar/api_go/internal/modules/rides/ports"
)

var (
	ErrDispatchServiceConfig = errors.New("dispatch service is not configured")
	ErrRideNotFound          = errors.New("ride not found")
	ErrRideNotSearching      = errors.New("ride is not searching")
	ErrOfferNotFound         = errors.New("offer not found")
	ErrOfferExpired          = errors.New("offer expired")
	ErrDriverNotEligible     = errors.New("driver not eligible")
	ErrDriverHasActiveRide   = errors.New("driver already has an active ride")
	ErrVehicleInvalid        = errors.New("vehicle is not valid for this driver or ride")
	ErrRideAlreadyAssigned   = errors.New("ride already assigned")
)

type DispatchService struct {
	db              *pgxpool.Pool
	offerRepo       ports.RideOfferRepository
	settingsRepo    ports.DispatchSettingsRepository
	driverRepo      ports.DriverRepository
	vehicleRepo     ports.VehicleRepository
	rideRepo        ridesports.RideRepository
	startCodeSecret []byte
	now             func() time.Time
}

type DispatchServiceConfig struct {
	DB              *pgxpool.Pool
	OfferRepo       ports.RideOfferRepository
	SettingsRepo    ports.DispatchSettingsRepository
	DriverRepo      ports.DriverRepository
	VehicleRepo     ports.VehicleRepository
	RideRepo        ridesports.RideRepository
	StartCodeSecret []byte
	Now             func() time.Time
}

func NewDispatchService(cfg DispatchServiceConfig) (*DispatchService, error) {
	if cfg.DB == nil || cfg.OfferRepo == nil || cfg.SettingsRepo == nil ||
		cfg.DriverRepo == nil || cfg.VehicleRepo == nil || cfg.RideRepo == nil {
		return nil, ErrDispatchServiceConfig
	}
	if len(cfg.StartCodeSecret) < 32 {
		return nil, errors.New("start code secret must be at least 32 bytes")
	}
	if cfg.Now == nil {
		cfg.Now = time.Now
	}
	return &DispatchService{
		db:              cfg.DB,
		offerRepo:       cfg.OfferRepo,
		settingsRepo:    cfg.SettingsRepo,
		driverRepo:      cfg.DriverRepo,
		vehicleRepo:     cfg.VehicleRepo,
		rideRepo:        cfg.RideRepo,
		startCodeSecret: append([]byte(nil), cfg.StartCodeSecret...),
		now:             cfg.Now,
	}, nil
}

// Search finds nearby drivers and creates ride offers.
func (s *DispatchService) Search(ctx context.Context, rideID string) (*SearchResult, error) {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	ride, err := s.rideRepo.FindRideForUpdate(ctx, rideID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRideNotFound
		}
		return nil, fmt.Errorf("find ride: %w", err)
	}
	if ride.Status != ride_state.StatusSearching || ride.DriverID != nil {
		return nil, ErrRideNotSearching
	}

	existing, err := s.offerRepo.FindPendingByRide(ctx, rideID)
	if err != nil {
		return nil, fmt.Errorf("find pending offers: %w", err)
	}
	if len(existing) > 0 {
		latestExpires := existing[0].ExpiresAt
		for _, o := range existing {
			if o.ExpiresAt > latestExpires {
				latestExpires = o.ExpiresAt
			}
		}
		return &SearchResult{
			RideID:    rideID,
			Offers:    existing,
			ExpiresAt: latestExpires,
			Replayed:  true,
		}, nil
	}

	if err := s.offerRepo.MarkExpired(ctx); err != nil {
		return nil, fmt.Errorf("mark expired offers: %w", err)
	}

	settings, found, err := s.settingsRepo.FindByServiceArea(ctx, ride.ServiceAreaID)
	if err != nil {
		return nil, fmt.Errorf("find dispatch settings: %w", err)
	}
	if !found {
		return nil, errors.New("no dispatch settings for area")
	}

	candidates, err := s.driverRepo.FindOnlineApprovedInArea(
		ctx, ride.ServiceAreaID, settings.LocationMaxAgeSeconds,
		settings.SearchRadiusM, ride.PickupLat, ride.PickupLon, settings.MaxCandidates,
	)
	if err != nil {
		return nil, fmt.Errorf("find candidates: %w", err)
	}

	batch := candidates
	if len(batch) > settings.OfferBatchSize {
		batch = batch[:settings.OfferBatchSize]
	}
	if len(batch) == 0 {
		return &SearchResult{
			RideID:    rideID,
			Offers:    nil,
			ExpiresAt: "",
			Replayed:  false,
		}, nil
	}

	roundNo := 1
	expiresAt := s.now().UTC().Add(time.Duration(settings.OfferTTLSeconds) * time.Second)

	var offers []ports.RideOffer
	for _, c := range batch {
		offer, err := s.offerRepo.Create(ctx, ports.RideOffer{
			RideID:            rideID,
			DriverID:          c.DriverID,
			Status:            "PENDING",
			RoundNo:           roundNo,
			DistanceToPickupM: intPtr(int64(c.DistanceM)),
			ExpiresAt:         expiresAt.Format(time.RFC3339Nano),
		})
		if err != nil {
			return nil, fmt.Errorf("create offer: %w", err)
		}
		offers = append(offers, offer)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit search: %w", err)
	}

	return &SearchResult{
		RideID:    rideID,
		Offers:    offers,
		ExpiresAt: expiresAt.Format(time.RFC3339Nano),
		Replayed:  false,
	}, nil
}

// AcceptOffer atomically assigns a ride to a driver.
func (s *DispatchService) AcceptOffer(ctx context.Context, offerID, driverID, vehicleID string) (*AcceptOfferResult, error) {
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var rideID string
	err = tx.QueryRow(context.Background(), "SELECT ride_id FROM ride_offers WHERE id = $1::uuid AND driver_id = $2::uuid", offerID, driverID).Scan(&rideID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrOfferNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("find offer ride id: %w", err)
	}

	ride, err := s.rideRepo.FindRideForUpdate(ctx, rideID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRideNotFound
		}
		return nil, fmt.Errorf("find ride: %w", err)
	}
	if ride.Status != ride_state.StatusSearching || ride.DriverID != nil {
		return nil, ErrRideAlreadyAssigned
	}

	offer, err := s.offerRepo.FindByIDAndDriver(ctx, offerID, driverID)
	if err != nil {
		if errors.Is(err, ports.ErrOfferNotFound) {
			return nil, ErrOfferNotFound
		}
		return nil, fmt.Errorf("find offer: %w", err)
	}
	if offer.Status != "PENDING" {
		return nil, ErrOfferExpired
	}
	if isExpired(offer.ExpiresAt) {
		return nil, ErrOfferExpired
	}

	profile, err := s.driverRepo.FindProfile(ctx, driverID)
	if err != nil {
		return nil, fmt.Errorf("find driver profile: %w", err)
	}
	if profile.VerificationStatus != "APPROVED" || !profile.IsOnline || profile.Status != "ACTIVE" {
		return nil, ErrDriverNotEligible
	}
	if profile.ServiceAreaID != ride.ServiceAreaID {
		return nil, ErrDriverNotEligible
	}

	hasActive, err := s.driverRepo.HasActiveRide(ctx, driverID)
	if err != nil {
		return nil, fmt.Errorf("check active ride: %w", err)
	}
	if hasActive {
		return nil, ErrDriverHasActiveRide
	}

	ok, err := s.vehicleRepo.FindActiveByDriverAndType(ctx, vehicleID, driverID, ride.VehicleTypeID)
	if err != nil {
		return nil, fmt.Errorf("find vehicle: %w", err)
	}
	if !ok {
		return nil, ErrVehicleInvalid
	}

	ttlMinutes := 15
	nonce, err := start_code.NewNonce()
	if err != nil {
		return nil, fmt.Errorf("generate start code nonce: %w", err)
	}
	startCodeExpiresAt := s.now().UTC().Add(time.Duration(ttlMinutes) * time.Minute)

	assigned, err := s.assignRide(tx, ride.ID, driverID, vehicleID, nonce, startCodeExpiresAt)
	if err != nil {
		return nil, err
	}
	if !assigned {
		return nil, ErrRideAlreadyAssigned
	}

	if _, err := s.offerRepo.UpdateStatus(ctx, offerID, "ACCEPTED"); err != nil {
		return nil, fmt.Errorf("accept offer: %w", err)
	}
	if err := s.offerRepo.UpdateManyStatus(ctx, ride.ID, offerID, "CANCELLED"); err != nil {
		return nil, fmt.Errorf("cancel other offers: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit acceptance: %w", err)
	}

	return &AcceptOfferResult{
		RideID:  ride.ID,
		OfferID: offerID,
		Status:  "ACCEPTED",
	}, nil
}

func (s *DispatchService) assignRide(tx pgx.Tx, rideID, driverID, vehicleID string, nonce []byte, expiresAt time.Time) (bool, error) {
	var id string
	err := tx.QueryRow(context.Background(), `
		UPDATE rides
		SET status = 'ASSIGNED',
		    driver_id = $2::uuid,
		    vehicle_id = $3::uuid,
		    assigned_at = now(),
		    start_code_nonce = $4,
		    start_code_expires_at = $5,
		    version = version + 1
		WHERE id = $1::uuid
		  AND status = 'SEARCHING'
		  AND driver_id IS NULL
		RETURNING id`,
		rideID, driverID, vehicleID, nonce, expiresAt).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("assign ride: %w", err)
	}
	return true, nil
}

func isExpired(expiresAt string) bool {
	t, err := time.Parse(time.RFC3339Nano, expiresAt)
	if err != nil {
		return true
	}
	return !time.Now().UTC().Before(t)
}

// Sweep expires pending offers and timed-out searches.
func (s *DispatchService) Sweep(ctx context.Context) (SweepResult, error) {
	if err := s.offerRepo.MarkExpired(ctx); err != nil {
		return SweepResult{}, fmt.Errorf("mark expired offers: %w", err)
	}
	if _, err := s.db.Exec(ctx, `
		UPDATE rides
		SET status = 'NO_DRIVER_FOUND', version = version + 1
		WHERE status = 'SEARCHING' AND search_expires_at < now()`); err != nil {
		return SweepResult{}, fmt.Errorf("expire searches: %w", err)
	}
	return SweepResult{Ok: true}, nil
}

func intPtr(i int64) *int64 { return &i }

type SearchResult struct {
	RideID    string
	Offers    []ports.RideOffer
	ExpiresAt string
	Replayed  bool
}

type AcceptOfferResult struct {
	RideID  string
	OfferID string
	Status  string
}

type SweepResult struct {
	Ok bool
}

var _ = time.Now
