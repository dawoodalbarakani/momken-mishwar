package pricing

import (
	"testing"
)

func mustRule() PricingRule {
	return PricingRule{
		ID:                "rule-1",
		Version:           1,
		Mode:              DISTANCE_TIME,
		Currency:          "YER",
		BaseFareMinor:     1000,
		PerKmMinor:        200,
		PerMinuteMinor:    50,
		MinimumFareMinor:  1500,
		Surcharges:        []Surcharge{{Code: "NIGHT", Kind: PERCENT_BPS, Value: 1000}},
		CommissionBps:     1000,
		RoundingStepMinor: 100,
	}
}

func TestComputePriceDistanceTime(t *testing.T) {
	rule := mustRule()
	input := QuoteInput{DistanceMeters: 5000, DurationSeconds: 600}
	bp, err := ComputePrice(rule, input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// base=1000, distance=200*5=1000, time=50*10=500, subtotal=2500, min fare ok
	// surcharge=10% of 2500=250, running=2750, no discount, round to 100 -> 2800
	// commission=10% of 2800=280, driver net=2520
	if bp.TotalMinor != 2800 {
		t.Fatalf("total = %d, want 2800", bp.TotalMinor)
	}
	if bp.CommissionMinor != 280 {
		t.Fatalf("commission = %d, want 280", bp.CommissionMinor)
	}
	if bp.DriverNetMinor != 2520 {
		t.Fatalf("driver net = %d, want 2520", bp.DriverNetMinor)
	}
	if bp.DiscountMinor != 0 {
		t.Fatalf("discount = %d, want 0", bp.DiscountMinor)
	}
}

func TestComputePriceMinimumFareAdjustment(t *testing.T) {
	rule := mustRule()
	input := QuoteInput{DistanceMeters: 100, DurationSeconds: 10}
	// base=1000, distance=20, time=8, subtotal=1028 < 1500 -> adj=472, subtotal=1500
	// surcharge=150, running=1650, round to 100 -> 1700
	bp, err := ComputePrice(rule, input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if bp.TotalMinor != 1700 {
		t.Fatalf("total = %d, want 1700", bp.TotalMinor)
	}
}

func TestComputePriceDiscount(t *testing.T) {
	rule := mustRule()
	input := QuoteInput{
		DistanceMeters:  5000,
		DurationSeconds: 600,
		Discount:        &Discount{Code: "PROMO", Kind: DISCOUNT_PERCENT_BPS, Value: 1000}, // 10%
	}
	// base=1000, dist=1000, time=500, subtotal=2500, surcharge=250, running=2750
	// discount=10% of 2750=275, running=2475, round to 100 -> 2500
	bp, err := ComputePrice(rule, input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if bp.TotalMinor != 2500 {
		t.Fatalf("total = %d, want 2500", bp.TotalMinor)
	}
	if bp.DiscountMinor != 275 {
		t.Fatalf("discount = %d, want 275", bp.DiscountMinor)
	}
}

func TestComputePriceFixedRoute(t *testing.T) {
	rule := PricingRule{
		ID: "rule-fr", Version: 1, Mode: FIXED_ROUTE, Currency: "YER",
		BaseFareMinor: 0, PerKmMinor: 0, PerMinuteMinor: 0, MinimumFareMinor: 0,
		Surcharges: nil, CommissionBps: 1000, RoundingStepMinor: 1,
	}
	input := QuoteInput{FixedRoute: &FixedRouteMatch{ID: "fr-1", FareMinor: 5000}}
	bp, err := ComputePrice(rule, input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if bp.TotalMinor != 5000 {
		t.Fatalf("total = %d, want 5000", bp.TotalMinor)
	}
	if bp.FixedRouteID == nil || *bp.FixedRouteID != "fr-1" {
		t.Fatalf("fixedRouteID = %v, want fr-1", bp.FixedRouteID)
	}
}

func TestComputePriceManual(t *testing.T) {
	rule := PricingRule{
		ID: "rule-manual", Version: 1, Mode: MANUAL, Currency: "YER",
		BaseFareMinor: 0, PerKmMinor: 0, PerMinuteMinor: 0, MinimumFareMinor: 0,
		Surcharges: nil, CommissionBps: 1000, RoundingStepMinor: 1,
	}
	approvedBy := "staff-1"
	input := QuoteInput{ManualFareMinor: ptrInt64(7000), ManualApprovedBy: &approvedBy}
	bp, err := ComputePrice(rule, input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if bp.TotalMinor != 7000 {
		t.Fatalf("total = %d, want 7000", bp.TotalMinor)
	}
	if bp.ManualApprovedBy == nil || *bp.ManualApprovedBy != "staff-1" {
		t.Fatalf("manualApprovedBy = %v, want staff-1", bp.ManualApprovedBy)
	}
}

func TestComputePriceInvalidRule(t *testing.T) {
	rule := mustRule()
	rule.CommissionBps = 99999
	if _, err := ComputePrice(rule, QuoteInput{}); !IsPricingError(err, ErrCodeInvalidRule) {
		t.Fatalf("expected invalid rule, got %v", err)
	}
}

func TestComputePriceMissingFixedRoute(t *testing.T) {
	rule := PricingRule{Mode: FIXED_ROUTE, RoundingStepMinor: 1, Version: 1}
	if _, err := ComputePrice(rule, QuoteInput{}); !IsPricingError(err, ErrCodeFixedRouteRequired) {
		t.Fatalf("expected fixed route required, got %v", err)
	}
}

func TestComputePriceMissingManualFare(t *testing.T) {
	rule := PricingRule{Mode: MANUAL, RoundingStepMinor: 1, Version: 1}
	if _, err := ComputePrice(rule, QuoteInput{}); !IsPricingError(err, ErrCodeManualFareRequired) {
		t.Fatalf("expected manual fare required, got %v", err)
	}
}

func ptrInt64(v int64) *int64 { return &v }
