package ports

import (
	"context"
)

type PaymentRecord struct {
	ID                string
	RideID            string
	Method            string
	Status            string
	AmountMinor       int64
	CurrencyCode      string
	Provider          *string
	ProviderReference *string
	CollectedAt       *string
	ReconciledBy      *string
	ReconciledAt      *string
	CreatedAt         string
	UpdatedAt         string
}

type PaymentRepository interface {
	Create(ctx context.Context, record PaymentRecord) (PaymentRecord, error)
	List(ctx context.Context, status *string, limit int, offset int) ([]PaymentRecord, error)
	FindByRide(ctx context.Context, rideID string) (PaymentRecord, bool, error)
	UpdateStatus(ctx context.Context, id string, status string, collectedAt *string, reconciledBy *string) (PaymentRecord, error)
}

var ErrPaymentNotFound = paymentNotFoundError{}

type paymentNotFoundError struct{}

func (paymentNotFoundError) Error() string        { return "payment record not found" }
func (paymentNotFoundError) Is(target error) bool { _, ok := target.(paymentNotFoundError); return ok }

type DriverPayout struct {
	ID           string
	DriverID     string
	Direction    string
	AmountMinor  int64
	CurrencyCode string
	Status       string
	Method       *string
	Reference    *string
	Note         *string
	RequestedBy  string
	ReviewedBy   *string
	ReviewedAt   *string
	CreatedAt    string
	UpdatedAt    string
}

type PayoutRepository interface {
	Create(ctx context.Context, payout DriverPayout) (DriverPayout, error)
	List(ctx context.Context, status *string, limit int, offset int) ([]DriverPayout, error)
	FindByID(ctx context.Context, id string) (DriverPayout, bool, error)
	Approve(ctx context.Context, id string, reviewerID string) (DriverPayout, error)
}

var ErrPayoutNotFound = payoutNotFoundError{}

type payoutNotFoundError struct{}

func (payoutNotFoundError) Error() string        { return "payout not found" }
func (payoutNotFoundError) Is(target error) bool { _, ok := target.(payoutNotFoundError); return ok }

type DriverLedgerEntry struct {
	ID             string
	DriverID       string
	RideID         *string
	PayoutID       *string
	EntryType      string
	AmountMinor    int64
	CurrencyCode   string
	IdempotencyKey string
	Memo           *string
	CreatedBy      *string
	CreatedAt      string
}

type LedgerRepository interface {
	Create(ctx context.Context, entry DriverLedgerEntry) (DriverLedgerEntry, error)
	ListByDriver(ctx context.Context, driverID string, currency *string, limit int, offset int) ([]DriverLedgerEntry, error)
	Balance(ctx context.Context, driverID string, currency string) (int64, error)
	SettleCashRide(ctx context.Context, rideID, driverID, currency string, grossMinor, commissionMinor, driverNetMinor int64, idempotencyKey string) error
}
