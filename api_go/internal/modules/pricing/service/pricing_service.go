package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/domain/pricing"
)

var ErrPricingServiceConfig = errors.New("pricing service is not configured")

type PricingService struct {
	db *pgxpool.Pool
}

func NewPricingService(db *pgxpool.Pool) (*PricingService, error) {
	if db == nil {
		return nil, ErrPricingServiceConfig
	}
	return &PricingService{db: db}, nil
}

type surchargeJSON struct {
	Code  string  `json:"code"`
	Kind  string  `json:"kind"`
	Value float64 `json:"value"`
}

func (s *PricingService) Quote(ctx context.Context, serviceAreaID, vehicleTypeID string, pickupLat, pickupLon, destLat, destLon float64) (pricing.PriceBreakdown, int64, int64, error) {
	var ruleID string
	var version int
	var mode, currency string
	var baseFare, perKm, perMinute, minimumFare, roundingStep float64
	var commissionBps int
	var surchargesJSON []byte

	err := s.db.QueryRow(ctx, `
		SELECT id, version, mode, currency_code, base_fare, per_km, per_minute,
		       minimum_fare, surcharges, commission_bps, rounding_step
		FROM pricing_rules
		WHERE service_area_id = $1::uuid
		  AND vehicle_type_id = $2::uuid
		  AND status = 'ACTIVE'
		ORDER BY version DESC
		LIMIT 1`, serviceAreaID, vehicleTypeID).Scan(
		&ruleID, &version, &mode, &currency, &baseFare, &perKm, &perMinute,
		&minimumFare, &surchargesJSON, &commissionBps, &roundingStep,
	)
	if err != nil {
		return pricing.PriceBreakdown{}, 0, 0, fmt.Errorf("no active pricing rule: %w", err)
	}

	var distanceMeters float64
	err = s.db.QueryRow(ctx, `
		SELECT ST_Distance(
			ST_SetSRID(ST_MakePoint($1, $2)::geometry, 4326)::geography,
			ST_SetSRID(ST_MakePoint($3, $4)::geometry, 4326)::geography
		)`, pickupLon, pickupLat, destLon, destLat).Scan(&distanceMeters)
	if err != nil {
		return pricing.PriceBreakdown{}, 0, 0, fmt.Errorf("compute distance: %w", err)
	}
	distanceM := int64(distanceMeters)
	durationS := (distanceM + 4) / 5

	var surcharges []pricing.Surcharge
	if len(surchargesJSON) > 0 {
		var raw []surchargeJSON
		if err := json.Unmarshal(surchargesJSON, &raw); err != nil {
			return pricing.PriceBreakdown{}, 0, 0, fmt.Errorf("parse surcharges: %w", err)
		}
		for _, r := range raw {
			var kind pricing.SurchargeKind
			switch r.Kind {
			case "FLAT":
				kind = pricing.FLAT
			case "PERCENT_BPS":
				kind = pricing.PERCENT_BPS
			default:
				kind = pricing.FLAT
			}
			surcharges = append(surcharges, pricing.Surcharge{
				Code:  r.Code,
				Kind:  kind,
				Value: floatToMinor(r.Value),
			})
		}
	}

	rule := pricing.PricingRule{
		ID:                ruleID,
		Version:           version,
		Mode:              pricing.PricingMode(mode),
		Currency:          currency,
		BaseFareMinor:     floatToMinor(baseFare),
		PerKmMinor:        floatToMinor(perKm),
		PerMinuteMinor:    floatToMinor(perMinute),
		MinimumFareMinor:  floatToMinor(minimumFare),
		Surcharges:        surcharges,
		CommissionBps:     commissionBps,
		RoundingStepMinor: floatToMinor(roundingStep),
	}

	input := pricing.QuoteInput{
		DistanceMeters:  distanceM,
		DurationSeconds: durationS,
	}

	breakdown, err := pricing.ComputePrice(rule, input)
	if err != nil {
		return pricing.PriceBreakdown{}, 0, 0, fmt.Errorf("compute price: %w", err)
	}

	return breakdown, distanceM, int64(durationS), nil
}

func floatToMinor(f float64) int64 {
	if f < 0 {
		return int64(f - 0.5)
	}
	return int64(f + 0.5)
}
