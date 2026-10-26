package service

import (
	"context"
	"errors"
	"fmt"

	pgxpool "github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/drivers/ports"
)

var ErrDriverServiceConfig = errors.New("driver service is not configured")

type DriverService struct {
	db        *pgxpool.Pool
	repo      ports.DriverRepository
	vehRepo   ports.VehicleRepository
	custRepo  ports.CustomerRepository
	savedRepo ports.SavedPlaceRepository
}

type DriverServiceConfig struct {
	DB        *pgxpool.Pool
	Repo      ports.DriverRepository
	VehRepo   ports.VehicleRepository
	CustRepo  ports.CustomerRepository
	SavedRepo ports.SavedPlaceRepository
}

func NewDriverService(cfg DriverServiceConfig) (*DriverService, error) {
	if cfg.DB == nil || cfg.Repo == nil {
		return nil, ErrDriverServiceConfig
	}
	return &DriverService{
		db:        cfg.DB,
		repo:      cfg.Repo,
		vehRepo:   cfg.VehRepo,
		custRepo:  cfg.CustRepo,
		savedRepo: cfg.SavedRepo,
	}, nil
}

func (s *DriverService) GetProfile(ctx context.Context, userID string) (*ports.DriverProfile, error) {
	profile, found, err := s.repo.FindByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("find driver profile: %w", err)
	}
	if !found {
		return nil, errors.New("driver profile not found")
	}
	return &profile, nil
}

func (s *DriverService) SetOnline(ctx context.Context, userID string, isOnline bool) (*ports.DriverProfile, error) {
	profile, err := s.repo.SetOnline(ctx, userID, isOnline)
	if err != nil {
		return nil, fmt.Errorf("set online: %w", err)
	}
	return &profile, nil
}

func (s *DriverService) List(ctx context.Context, serviceAreaID *string, limit int, offset int) ([]ports.DriverProfile, error) {
	if limit > 100 {
		limit = 100
	}
	return s.repo.List(ctx, serviceAreaID, limit, offset)
}

type CreateVehicleParams struct {
	DriverID      string
	VehicleTypeID string
	PlateNumber   string
	Make          *string
	Model         *string
	Year          *int
	Color         *string
}

func (s *DriverService) CreateVehicle(ctx context.Context, params CreateVehicleParams) (*ports.Vehicle, error) {
	if params.DriverID == "" || params.VehicleTypeID == "" || params.PlateNumber == "" {
		return nil, errors.New("driver_id, vehicle_type_id, and plate_number are required")
	}
	v, err := s.vehRepo.Create(ctx, ports.Vehicle{
		DriverID:      params.DriverID,
		VehicleTypeID: params.VehicleTypeID,
		PlateNumber:   params.PlateNumber,
		Make:          params.Make,
		Model:         params.Model,
		Year:          params.Year,
		Color:         params.Color,
		IsActive:      true,
	})
	if err != nil {
		return nil, fmt.Errorf("create vehicle: %w", err)
	}
	return &v, nil
}

func (s *DriverService) ListVehicles(ctx context.Context, driverID string) ([]ports.Vehicle, error) {
	return s.vehRepo.ListForDriver(ctx, driverID)
}

func (s *DriverService) GetOrCreateCustomerProfile(ctx context.Context, userID string) (*ports.CustomerProfile, error) {
	p, err := s.custRepo.GetOrCreate(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get or create customer profile: %w", err)
	}
	return &p, nil
}

func (s *DriverService) ListSavedPlaces(ctx context.Context, customerID string) ([]ports.SavedPlace, error) {
	return s.savedRepo.List(ctx, customerID)
}

func (s *DriverService) AddSavedPlace(ctx context.Context, customerID string, label string, addressText *string, lat, lon float64) (*ports.SavedPlace, error) {
	if label == "" {
		return nil, errors.New("label is required")
	}
	p, err := s.savedRepo.Create(ctx, ports.SavedPlace{
		CustomerID:  customerID,
		Label:       label,
		AddressText: addressText,
		LocationLat: lat,
		LocationLon: lon,
	})
	if err != nil {
		return nil, fmt.Errorf("add saved place: %w", err)
	}
	return &p, nil
}
