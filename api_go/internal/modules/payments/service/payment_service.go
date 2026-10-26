package service

import (
	"context"
	"errors"
	"fmt"

	pgxpool "github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/payments/ports"
)

var ErrPaymentsServiceConfig = errors.New("payments service is not configured")

type PaymentService struct {
	db         *pgxpool.Pool
	repo       ports.PaymentRepository
	ledger     ports.LedgerRepository
	payoutRepo ports.PayoutRepository
}

type PaymentServiceConfig struct {
	DB         *pgxpool.Pool
	Repo       ports.PaymentRepository
	Ledger     ports.LedgerRepository
	PayoutRepo ports.PayoutRepository
}

func NewPaymentService(cfg PaymentServiceConfig) (*PaymentService, error) {
	if cfg.DB == nil || cfg.Repo == nil {
		return nil, ErrPaymentsServiceConfig
	}
	return &PaymentService{
		db:         cfg.DB,
		repo:       cfg.Repo,
		ledger:     cfg.Ledger,
		payoutRepo: cfg.PayoutRepo,
	}, nil
}

type CreatePaymentParams struct {
	RideID         string
	AmountMinor    int64
	CurrencyCode   string
	Method         string
	IdempotencyKey string
}

func (s *PaymentService) CreateForRide(ctx context.Context, params CreatePaymentParams) (*ports.PaymentRecord, error) {
	if params.RideID == "" || params.AmountMinor <= 0 || params.Method != "CASH" {
		return nil, errors.New("invalid payment parameters")
	}
	record, err := s.repo.Create(ctx, ports.PaymentRecord{
		RideID:       params.RideID,
		Method:       params.Method,
		Status:       "PENDING",
		AmountMinor:  params.AmountMinor,
		CurrencyCode: params.CurrencyCode,
	})
	if err != nil {
		return nil, fmt.Errorf("create payment: %w", err)
	}
	return &record, nil
}

func (s *PaymentService) List(ctx context.Context, status *string, limit int, offset int) ([]ports.PaymentRecord, error) {
	if limit > 100 {
		limit = 100
	}
	return s.repo.List(ctx, status, limit, offset)
}

type CreatePayoutParams struct {
	DriverID     string
	AmountMinor  int64
	CurrencyCode string
	Method       *string
	Reference    *string
	Note         *string
	RequestedBy  string
}

func (s *PaymentService) RequestPayout(ctx context.Context, params CreatePayoutParams) (*ports.DriverPayout, error) {
	if params.DriverID == "" || params.AmountMinor <= 0 || params.RequestedBy == "" {
		return nil, errors.New("invalid payout parameters")
	}
	payout, err := s.payoutRepo.Create(ctx, ports.DriverPayout{
		DriverID:     params.DriverID,
		Direction:    "PLATFORM_TO_DRIVER",
		AmountMinor:  params.AmountMinor,
		CurrencyCode: params.CurrencyCode,
		Status:       "PENDING",
		Method:       params.Method,
		Reference:    params.Reference,
		Note:         params.Note,
		RequestedBy:  params.RequestedBy,
	})
	if err != nil {
		return nil, fmt.Errorf("create payout: %w", err)
	}
	return &payout, nil
}

func (s *PaymentService) ListPayouts(ctx context.Context, status *string, limit int, offset int) ([]ports.DriverPayout, error) {
	if limit > 100 {
		limit = 100
	}
	return s.payoutRepo.List(ctx, status, limit, offset)
}

func (s *PaymentService) ApprovePayout(ctx context.Context, payoutID string, reviewerID string) (*ports.DriverPayout, error) {
	payout, found, err := s.payoutRepo.FindByID(ctx, payoutID)
	if err != nil {
		return nil, fmt.Errorf("find payout: %w", err)
	}
	if !found {
		return nil, errors.New("payout not found")
	}
	if payout.RequestedBy == reviewerID {
		return nil, errors.New("four-eyes: reviewer cannot be requester")
	}
	approved, err := s.payoutRepo.Approve(ctx, payoutID, reviewerID)
	if err != nil {
		return nil, fmt.Errorf("approve payout: %w", err)
	}
	return &approved, nil
}

type DriverBalance struct {
	DriverID     string
	Currency     string
	BalanceMinor int64
	EntryCount   int
	LastEntryAt  *string
}

func (s *PaymentService) DriverBalance(ctx context.Context, driverID string, currency string) (*DriverBalance, error) {
	balance, err := s.ledger.Balance(ctx, driverID, currency)
	if err != nil {
		return nil, fmt.Errorf("ledger balance: %w", err)
	}
	return &DriverBalance{
		DriverID:     driverID,
		Currency:     currency,
		BalanceMinor: balance,
	}, nil
}
