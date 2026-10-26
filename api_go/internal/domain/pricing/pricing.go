package pricing

import (
	"errors"
	"fmt"

	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/money"
)

// PricingMode is the fare calculation mode.
type PricingMode string

const (
	// FIXED_ROUTE is an admin-defined fare for a pickup-zone -> destination-zone pair.
	FIXED_ROUTE PricingMode = "FIXED_ROUTE"
	// DISTANCE_TIME is base + distance + time with a minimum fare.
	DISTANCE_TIME PricingMode = "DISTANCE_TIME"
	// MANUAL is an operator-approved fare requiring an approver reference.
	MANUAL PricingMode = "MANUAL"
)

// Surcharge is a line item added to the fare subtotal.
type Surcharge struct {
	Code string
	Kind SurchargeKind
	// FLAT: minor units. PERCENT_BPS: basis points (100 bps = 1%).
	Value int64
}

type SurchargeKind string

const (
	FLAT        SurchargeKind = "FLAT"
	PERCENT_BPS SurchargeKind = "PERCENT_BPS"
)

// Discount is a reduction applied after surcharges.
type Discount struct {
	Code     string
	Kind     DiscountKind
	Value    int64
	MaxMinor *int64 // optional cap on the discount, in minor units
}

type DiscountKind string

const (
	DISCOUNT_FLAT        DiscountKind = "FLAT"
	DISCOUNT_PERCENT_BPS DiscountKind = "PERCENT_BPS"
)

// PricingRule is a versioned, immutable-once-published fare rule.
type PricingRule struct {
	ID               string
	Version          int
	Mode             PricingMode
	Currency         string
	BaseFareMinor    int64
	PerKmMinor       int64
	PerMinuteMinor   int64
	MinimumFareMinor int64
	Surcharges       []Surcharge
	// CommissionBps is the platform commission in basis points of the final total (0..10000).
	CommissionBps int
	// RoundingStepMinor rounds the final total to a multiple of this (>= 1).
	RoundingStepMinor int64
}

// FixedRouteMatch is a matched fixed-route fare.
type FixedRouteMatch struct {
	ID        string
	FareMinor int64
}

// QuoteInput contains the inputs to compute a price quote.
type QuoteInput struct {
	DistanceMeters  int64
	DurationSeconds int64
	// Required when rule.Mode == FIXED_ROUTE.
	FixedRoute *FixedRouteMatch
	// Required when rule.Mode == MANUAL.
	ManualFareMinor *int64
	// Staff user id that approved the manual fare. Required for MANUAL.
	ManualApprovedBy *string
	Discount         *Discount
}

// PriceLine is a single line in the fare breakdown.
type PriceLine struct {
	Code        string
	AmountMinor int64
}

// PriceBreakdown is the complete, server-computed fare snapshot.
type PriceBreakdown struct {
	Currency         string
	Mode             PricingMode
	RuleID           string
	RuleVersion      int
	DistanceMeters   int64
	DurationSeconds  int64
	Lines            []PriceLine
	DiscountMinor    int64
	TotalMinor       int64
	CommissionBps    int
	CommissionMinor  int64
	DriverNetMinor   int64
	FixedRouteID     *string
	ManualApprovedBy *string
	// Estimated is true for quotes: distance/time are estimates until the trip completes.
	Estimated bool
}

var (
	ErrPricingConfig = errors.New("pricing rule is not configured")
)

// PricingError is returned by the pricing engine for invalid rules or inputs.
type PricingError struct {
	Code    string
	Message string
}

func (e *PricingError) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *PricingError) Unwrap() error { return errors.New(e.Message) }

const (
	ErrCodeInvalidRule            = "INVALID_RULE"
	ErrCodeInvalidInput           = "INVALID_INPUT"
	ErrCodeFixedRouteRequired     = "FIXED_ROUTE_REQUIRED"
	ErrCodeManualFareRequired     = "MANUAL_FARE_REQUIRED"
	ErrCodeManualApproverRequired = "MANUAL_APPROVER_REQUIRED"
)

func newPricingError(code, message string) *PricingError {
	return &PricingError{Code: code, Message: message}
}

// IsPricingError reports whether err is a PricingError with the given code.
func IsPricingError(err error, code string) bool {
	var e *PricingError
	return errors.As(err, &e) && e.Code == code
}

// ValidateRule checks the pricing rule invariants.
func ValidateRule(rule PricingRule) error {
	if err := money.AssertMinor(money.Minor(rule.BaseFareMinor), "baseFareMinor"); err != nil {
		return newPricingError(ErrCodeInvalidRule, err.Error())
	}
	if err := money.AssertMinor(money.Minor(rule.PerKmMinor), "perKmMinor"); err != nil {
		return newPricingError(ErrCodeInvalidRule, err.Error())
	}
	if err := money.AssertMinor(money.Minor(rule.PerMinuteMinor), "perMinuteMinor"); err != nil {
		return newPricingError(ErrCodeInvalidRule, err.Error())
	}
	if err := money.AssertMinor(money.Minor(rule.MinimumFareMinor), "minimumFareMinor"); err != nil {
		return newPricingError(ErrCodeInvalidRule, err.Error())
	}
	for _, s := range rule.Surcharges {
		if err := money.AssertMinor(money.Minor(s.Value), "surcharge "+s.Code); err != nil {
			return newPricingError(ErrCodeInvalidRule, err.Error())
		}
	}
	if rule.CommissionBps < 0 || rule.CommissionBps > 10_000 {
		return newPricingError(ErrCodeInvalidRule, fmt.Sprintf("commissionBps must be 0..10000, got %d", rule.CommissionBps))
	}
	if rule.RoundingStepMinor < 1 {
		return newPricingError(ErrCodeInvalidRule, fmt.Sprintf("roundingStepMinor must be >= 1, got %d", rule.RoundingStepMinor))
	}
	if rule.Version < 1 {
		return newPricingError(ErrCodeInvalidRule, fmt.Sprintf("version must be >= 1, got %d", rule.Version))
	}
	return nil
}

// ValidateInput checks the quote input invariants.
func ValidateInput(input QuoteInput) error {
	if err := money.AssertMinor(money.Minor(input.DistanceMeters), "distanceMeters"); err != nil {
		return newPricingError(ErrCodeInvalidInput, err.Error())
	}
	if err := money.AssertMinor(money.Minor(input.DurationSeconds), "durationSeconds"); err != nil {
		return newPricingError(ErrCodeInvalidInput, err.Error())
	}
	if input.Discount != nil {
		if err := money.AssertMinor(money.Minor(input.Discount.Value), "discount.value"); err != nil {
			return newPricingError(ErrCodeInvalidInput, err.Error())
		}
		if input.Discount.MaxMinor != nil {
			if err := money.AssertMinor(money.Minor(*input.Discount.MaxMinor), "discount.maxMinor"); err != nil {
				return newPricingError(ErrCodeInvalidInput, err.Error())
			}
		}
	}
	return nil
}

// ComputePrice produces a server-computed fare snapshot from a rule and inputs.
// It is pure: no I/O, no database access.
func ComputePrice(rule PricingRule, input QuoteInput) (PriceBreakdown, error) {
	if err := ValidateRule(rule); err != nil {
		return PriceBreakdown{}, err
	}
	if err := ValidateInput(input); err != nil {
		return PriceBreakdown{}, err
	}

	var lines []PriceLine
	var discountMinor int64
	var totalMinor int64
	var fixedRouteID *string
	var manualApprovedBy *string

	if rule.Mode == MANUAL {
		if input.ManualFareMinor == nil {
			return PriceBreakdown{}, newPricingError(ErrCodeManualFareRequired, "MANUAL pricing requires manualFareMinor")
		}
		if input.ManualApprovedBy == nil || *input.ManualApprovedBy == "" {
			return PriceBreakdown{}, newPricingError(ErrCodeManualApproverRequired, "MANUAL pricing requires manualApprovedBy")
		}
		if err := money.AssertMinor(money.Minor(*input.ManualFareMinor), "manualFareMinor"); err != nil {
			return PriceBreakdown{}, newPricingError(ErrCodeInvalidInput, err.Error())
		}
		lines = append(lines, PriceLine{Code: "MANUAL_FARE", AmountMinor: *input.ManualFareMinor})
		totalMinor = *input.ManualFareMinor
		manualApprovedBy = input.ManualApprovedBy
	} else {
		var subtotal int64
		if rule.Mode == FIXED_ROUTE {
			if input.FixedRoute == nil {
				return PriceBreakdown{}, newPricingError(ErrCodeFixedRouteRequired, "FIXED_ROUTE pricing requires a matched fixed route")
			}
			if err := money.AssertMinor(money.Minor(input.FixedRoute.FareMinor), "fixedRoute.fareMinor"); err != nil {
				return PriceBreakdown{}, newPricingError(ErrCodeInvalidInput, err.Error())
			}
			lines = append(lines, PriceLine{Code: "FIXED_ROUTE_FARE", AmountMinor: input.FixedRoute.FareMinor})
			subtotal = input.FixedRoute.FareMinor
			fixedRouteID = &input.FixedRoute.ID
		} else {
			// DISTANCE_TIME: base + distance + time
			distance, err := money.MulDivRound(money.Minor(rule.PerKmMinor), money.Minor(input.DistanceMeters), 1000)
			if err != nil {
				return PriceBreakdown{}, newPricingError(ErrCodeInvalidInput, err.Error())
			}
			timeAmt, err := money.MulDivRound(money.Minor(rule.PerMinuteMinor), money.Minor(input.DurationSeconds), 60)
			if err != nil {
				return PriceBreakdown{}, newPricingError(ErrCodeInvalidInput, err.Error())
			}
			lines = append(lines,
				PriceLine{Code: "BASE_FARE", AmountMinor: rule.BaseFareMinor},
				PriceLine{Code: "DISTANCE", AmountMinor: int64(distance)},
				PriceLine{Code: "TIME", AmountMinor: int64(timeAmt)},
			)
			subtotal = rule.BaseFareMinor + int64(distance) + int64(timeAmt)

			if subtotal < rule.MinimumFareMinor {
				adj := rule.MinimumFareMinor - subtotal
				lines = append(lines, PriceLine{Code: "MINIMUM_FARE_ADJUSTMENT", AmountMinor: adj})
				subtotal += adj
			}
		}

		preSurcharge := subtotal
		running := subtotal
		for _, s := range rule.Surcharges {
			var amount int64
			if s.Kind == FLAT {
				amount = s.Value
			} else {
				a, err := money.MulDivRound(money.Minor(preSurcharge), money.Minor(s.Value), 10_000)
				if err != nil {
					return PriceBreakdown{}, newPricingError(ErrCodeInvalidInput, err.Error())
				}
				amount = int64(a)
			}
			if amount > 0 {
				lines = append(lines, PriceLine{Code: "SURCHARGE_" + s.Code, AmountMinor: amount})
				running += amount
			}
		}

		if input.Discount != nil {
			d := input.Discount
			var amount int64
			if d.Kind == DISCOUNT_FLAT {
				amount = d.Value
			} else {
				a, err := money.MulDivRound(money.Minor(running), money.Minor(d.Value), 10_000)
				if err != nil {
					return PriceBreakdown{}, newPricingError(ErrCodeInvalidInput, err.Error())
				}
				amount = int64(a)
			}
			if d.MaxMinor != nil && amount > *d.MaxMinor {
				amount = *d.MaxMinor
			}
			if amount > running {
				amount = running
			}
			discountMinor = amount
			if amount > 0 {
				lines = append(lines, PriceLine{Code: "DISCOUNT_" + d.Code, AmountMinor: -amount})
				running -= amount
			}
		}

		rounded, err := money.RoundToStep(money.Minor(running), money.Minor(rule.RoundingStepMinor))
		if err != nil {
			return PriceBreakdown{}, newPricingError(ErrCodeInvalidInput, err.Error())
		}
		if int64(rounded) != running {
			lines = append(lines, PriceLine{Code: "ROUNDING", AmountMinor: int64(rounded) - running})
		}
		totalMinor = int64(rounded)
	}

	commissionMinor, err := money.MulDivRound(money.Minor(totalMinor), money.Minor(rule.CommissionBps), 10_000)
	if err != nil {
		return PriceBreakdown{}, newPricingError(ErrCodeInvalidInput, err.Error())
	}
	driverNetMinor := totalMinor - int64(commissionMinor)

	return PriceBreakdown{
		Currency:         rule.Currency,
		Mode:             rule.Mode,
		RuleID:           rule.ID,
		RuleVersion:      rule.Version,
		DistanceMeters:   input.DistanceMeters,
		DurationSeconds:  input.DurationSeconds,
		Lines:            lines,
		DiscountMinor:    discountMinor,
		TotalMinor:       totalMinor,
		CommissionBps:    rule.CommissionBps,
		CommissionMinor:  int64(commissionMinor),
		DriverNetMinor:   driverNetMinor,
		FixedRouteID:     fixedRouteID,
		ManualApprovedBy: manualApprovedBy,
		Estimated:        true,
	}, nil
}
