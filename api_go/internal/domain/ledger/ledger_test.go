package ledger

import (
	"testing"
)

func TestBuildCashRideEntriesBalances(t *testing.T) {
	entries, err := BuildCashRideEntries(CashRideSettlementInput{
		RideID:          "ride-1",
		DriverID:        "driver-1",
		Currency:        "YER",
		GrossMinor:      10000,
		CommissionMinor: 2000,
		DriverNetMinor:  8000,
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	earning := entries[0]
	cash := entries[1]
	if earning.EntryType != EntryEarning || earning.AmountMinor != 8000 {
		t.Fatalf("unexpected earning: %+v", earning)
	}
	if cash.EntryType != EntryCashCollected || cash.AmountMinor != -10000 {
		t.Fatalf("unexpected cash collected: %+v", cash)
	}
	balance, err := BalanceMinor(entries, "YER")
	if err != nil || balance != -2000 {
		t.Fatalf("balance = %d, want -2000 (commission owed to platform)", balance)
	}
}

func TestBuildCashRideEntriesZeroNetOmitsEarning(t *testing.T) {
	entries, err := BuildCashRideEntries(CashRideSettlementInput{
		RideID:          "ride-1",
		DriverID:        "driver-1",
		Currency:        "YER",
		GrossMinor:      5000,
		CommissionMinor: 5000,
		DriverNetMinor:  0,
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 {
		t.Fatalf("expected 1 entry (zero net omits earning), got %d", len(entries))
	}
	if entries[0].EntryType != EntryCashCollected || entries[0].AmountMinor != -5000 {
		t.Fatalf("unexpected entry: %+v", entries[0])
	}
}

func TestBuildCashRideEntriesUnbalanced(t *testing.T) {
	_, err := BuildCashRideEntries(CashRideSettlementInput{
		RideID:          "ride-1",
		DriverID:        "driver-1",
		Currency:        "YER",
		GrossMinor:      10000,
		CommissionMinor: 1000,
		DriverNetMinor:  8000, // 1000+8000 != 10000
	})
	if !IsLedgerError(err, ErrCodeAmountsDoNotBalance) {
		t.Fatalf("expected unbalanced error, got %v", err)
	}
}

func TestBuildSettlementEntry(t *testing.T) {
	e, err := BuildSettlementInput(SettlementInput{
		DriverID:    "driver-1",
		PayoutID:    "payout-1",
		Currency:    "YER",
		AmountMinor: 3000,
		Direction:   "DRIVER_TO_PLATFORM",
	})
	if err != nil {
		t.Fatal(err)
	}
	if e.EntryType != EntrySettlementFromDriver || e.AmountMinor != 3000 {
		t.Fatalf("unexpected from-driver entry: %+v", e)
	}
	e2, err := BuildSettlementInput(SettlementInput{
		DriverID:    "driver-1",
		PayoutID:    "payout-1",
		Currency:    "YER",
		AmountMinor: 3000,
		Direction:   "PLATFORM_TO_DRIVER",
	})
	if err != nil {
		t.Fatal(err)
	}
	if e2.EntryType != EntrySettlementToDriver || e2.AmountMinor != -3000 {
		t.Fatalf("unexpected to-driver entry: %+v", e2)
	}
}

func TestBuildSettlementInvalidAmount(t *testing.T) {
	_, err := BuildSettlementInput(SettlementInput{
		DriverID:    "driver-1",
		PayoutID:    "payout-1",
		Currency:    "YER",
		AmountMinor: 0,
		Direction:   "DRIVER_TO_PLATFORM",
	})
	if !IsLedgerError(err, ErrCodeInvalidAmount) {
		t.Fatalf("expected invalid amount error, got %v", err)
	}
}

func TestBalanceMixedCurrency(t *testing.T) {
	entries := []EntryDraft{
		{DriverID: "d", Currency: "YER", AmountMinor: 100},
		{DriverID: "d", Currency: "USD", AmountMinor: 200},
	}
	_, err := BalanceMinor(entries, "YER")
	if !IsLedgerError(err, ErrCodeMixedCurrency) {
		t.Fatalf("expected mixed currency error, got %v", err)
	}
}
