package ledger

import (
	"errors"
	"fmt"
)

// EntryType is the type of a driver ledger entry.
type EntryType string

const (
	EntryEarning              EntryType = "EARNING"
	EntryCashCollected        EntryType = "CASH_COLLECTED"
	EntrySettlementFromDriver EntryType = "SETTLEMENT_FROM_DRIVER"
	EntrySettlementToDriver   EntryType = "SETTLEMENT_TO_DRIVER"
	EntryAdjustment           EntryType = "ADJUSTMENT"
	EntryReversal             EntryType = "REVERSAL"
)

// Sign convention (per driver, per currency):
//   amount > 0  -> the platform owes the driver
//   amount < 0  -> the driver owes the platform
//   balance     = SUM(amount)

// EntryDraft is a pending ledger entry to be persisted.
type EntryDraft struct {
	DriverID       string
	RideID         *string
	PayoutID       *string
	EntryType      EntryType
	AmountMinor    int64 // signed, never zero
	Currency       string
	IdempotencyKey string
	Memo           *string
	CreatedBy      *string
}

// LedgerError is returned for invalid ledger operations.
type LedgerError struct {
	Code    string
	Message string
}

func (e *LedgerError) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *LedgerError) Unwrap() error { return errors.New(e.Message) }

const (
	ErrCodeAmountsDoNotBalance = "AMOUNTS_DO_NOT_BALANCE"
	ErrCodeInvalidAmount       = "INVALID_AMOUNT"
	ErrCodeMixedCurrency       = "MIXED_CURRENCY"
)

func newLedgerError(code, message string) *LedgerError {
	return &LedgerError{Code: code, Message: message}
}

// IsLedgerError reports whether err is a LedgerError with the given code.
func IsLedgerError(err error, code string) bool {
	var e *LedgerError
	return errors.As(err, &e) && e.Code == code
}

// CashRideSettlementInput contains the values from a completed ride's stored
// price snapshot, never recomputed here.
type CashRideSettlementInput struct {
	RideID          string
	DriverID        string
	Currency        string
	GrossMinor      int64
	CommissionMinor int64
	DriverNetMinor  int64
}

// BuildCashRideEntries builds the ledger entries for a completed cash trip:
//
//	EARNING +N (driver earned N)
//	CASH_COLLECTED -F (driver physically holds F belonging to the platform flow)
//
// Balance change = N - F = -commission (driver owes platform the commission).
func BuildCashRideEntries(input CashRideSettlementInput) ([]EntryDraft, error) {
	if input.GrossMinor < 0 {
		return nil, newLedgerError(ErrCodeInvalidAmount, "grossMinor must be >= 0")
	}
	if input.CommissionMinor < 0 {
		return nil, newLedgerError(ErrCodeInvalidAmount, "commissionMinor must be >= 0")
	}
	if input.DriverNetMinor < 0 {
		return nil, newLedgerError(ErrCodeInvalidAmount, "driverNetMinor must be >= 0")
	}
	if input.CommissionMinor+input.DriverNetMinor != input.GrossMinor {
		return nil, newLedgerError(ErrCodeAmountsDoNotBalance,
			fmt.Sprintf("commission %d + driver net %d != gross %d",
				input.CommissionMinor, input.DriverNetMinor, input.GrossMinor))
	}

	// Zero-amount entries are not posted (DB CHECK amount <> 0).
	var entries []EntryDraft
	if input.DriverNetMinor != 0 {
		entries = append(entries, EntryDraft{
			DriverID:       input.DriverID,
			RideID:         strPtr(input.RideID),
			PayoutID:       nil,
			EntryType:      EntryEarning,
			AmountMinor:    input.DriverNetMinor,
			Currency:       input.Currency,
			IdempotencyKey: "ride:" + input.RideID + ":EARNING",
			Memo:           nil,
			CreatedBy:      nil,
		})
	}
	if input.GrossMinor != 0 {
		entries = append(entries, EntryDraft{
			DriverID:       input.DriverID,
			RideID:         strPtr(input.RideID),
			PayoutID:       nil,
			EntryType:      EntryCashCollected,
			AmountMinor:    -input.GrossMinor,
			Currency:       input.Currency,
			IdempotencyKey: "ride:" + input.RideID + ":CASH_COLLECTED",
			Memo:           nil,
			CreatedBy:      nil,
		})
	}
	return entries, nil
}

// SettlementInput contains the inputs for a payout settlement entry.
type SettlementInput struct {
	DriverID    string
	PayoutID    string
	Currency    string
	AmountMinor int64
	// DRIVER_TO_PLATFORM: driver hands cash over. PLATFORM_TO_DRIVER: platform pays the driver.
	Direction string
}

// BuildSettlementEntry builds a single settlement ledger entry.
func BuildSettlementInput(input SettlementInput) (EntryDraft, error) {
	if input.AmountMinor <= 0 {
		return EntryDraft{}, newLedgerError(ErrCodeInvalidAmount, "settlement amount must be > 0")
	}
	toPlatform := input.Direction == "DRIVER_TO_PLATFORM"
	entryType := EntrySettlementToDriver
	amount := input.AmountMinor
	if toPlatform {
		entryType = EntrySettlementFromDriver
	} else {
		amount = -input.AmountMinor // platform pays driver -> credit shrinks
	}
	return EntryDraft{
		DriverID:    input.DriverID,
		RideID:      nil,
		PayoutID:    strPtr(input.PayoutID),
		EntryType:   entryType,
		AmountMinor: amount,
		Currency:    input.Currency,
		IdempotencyKey: "payout:" + input.PayoutID + ":" + func() string {
			if toPlatform {
				return "FROM_DRIVER"
			}
			return "TO_DRIVER"
		}(),
		Memo:      nil,
		CreatedBy: nil,
	}, nil
}

// BalanceMinor sums entry amounts for a single currency, returning the balance.
// amount > 0 means platform owes driver; amount < 0 means driver owes platform.
func BalanceMinor(entries []EntryDraft, currency string) (int64, error) {
	var sum int64
	for _, e := range entries {
		if e.Currency != currency {
			return 0, newLedgerError(ErrCodeMixedCurrency,
				fmt.Sprintf("entry currency %s != %s", e.Currency, currency))
		}
		sum += e.AmountMinor
	}
	return sum, nil
}

func strPtr(s string) *string { return &s }
