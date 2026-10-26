package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/admin/ports"
)

type AdminRepository struct {
	db *pgxpool.Pool
}

func NewAdminRepository(db *pgxpool.Pool) *AdminRepository {
	return &AdminRepository{db: db}
}

func (r *AdminRepository) ListDrivers(ctx context.Context, status *string, limit int, offset int) ([]ports.AdminDriver, error) {
	if r.db == nil {
		return nil, errors.New("admin repository: nil database")
	}
	query := `SELECT dp.user_id::text, u.phone_e164, dp.full_name, dp.verification_status,
		dp.is_online, dp.rating_avg, dp.rating_count, dp.created_at
		FROM driver_profiles dp JOIN users u ON u.id = dp.user_id`
	args := []interface{}{}
	argIdx := 1
	if status != nil {
		query += " WHERE dp.verification_status = $" + argNum(argIdx)
		args = append(args, *status)
		argIdx++
	}
	query += " ORDER BY dp.created_at DESC LIMIT $" + argNum(argIdx)
	args = append(args, limit)
	argIdx++
	query += " OFFSET $" + argNum(argIdx)
	args = append(args, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list drivers: %w", err)
	}
	defer rows.Close()

	var drivers []ports.AdminDriver
	for rows.Next() {
		var d ports.AdminDriver
		var phone sql.NullString
		var name sql.NullString
		var ratingAvg sql.NullFloat64
		if err := rows.Scan(&d.UserID, &phone, &name, &d.VerificationStatus, &d.IsOnline,
			&ratingAvg, &d.RatingCount, &d.CreatedAt); err != nil {
			return nil, err
		}
		if phone.Valid {
			d.PhoneE164 = strPtr(phone.String)
		}
		if name.Valid {
			d.DisplayName = strPtr(name.String)
		}
		if ratingAvg.Valid {
			d.RatingAvg = &ratingAvg.Float64
		}
		drivers = append(drivers, d)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return drivers, nil
}

func (r *AdminRepository) ListRides(ctx context.Context, status *string, limit int, offset int) ([]ports.AdminRide, error) {
	if r.db == nil {
		return nil, errors.New("admin repository: nil database")
	}
	query := `SELECT id::text, ride_number, customer_id::text, driver_id::text, status,
		quoted_total, currency_code, requested_at, created_at FROM rides`
	args := []interface{}{}
	argIdx := 1
	if status != nil {
		query += " WHERE status = $" + argNum(argIdx)
		args = append(args, *status)
		argIdx++
	}
	query += " ORDER BY requested_at DESC LIMIT $" + argNum(argIdx)
	args = append(args, limit)
	argIdx++
	query += " OFFSET $" + argNum(argIdx)
	args = append(args, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list rides: %w", err)
	}
	defer rows.Close()

	var rides []ports.AdminRide
	for rows.Next() {
		var r ports.AdminRide
		var driverID sql.NullString
		if err := rows.Scan(&r.ID, &r.RideNumber, &r.CustomerID, &driverID, &r.Status,
			&r.QuotedTotalMinor, &r.CurrencyCode, &r.RequestedAt, &r.CreatedAt); err != nil {
			return nil, err
		}
		if driverID.Valid {
			r.DriverID = strPtr(driverID.String)
		}
		rides = append(rides, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return rides, nil
}

func (r *AdminRepository) CancelRide(ctx context.Context, rideID, reason, staffID string) error {
	if r.db == nil {
		return errors.New("admin repository: nil database")
	}
	_, err := r.db.Exec(ctx, `
		UPDATE rides SET status = 'CANCELLED', cancelled_by_role = 'STAFF',
			cancelled_by_user_id = $2::uuid, cancel_reason_code = $3,
			cancelled_at = now(), version = version + 1
		WHERE id = $1::uuid AND status NOT IN ('COMPLETED', 'CANCELLED', 'NO_DRIVER_FOUND')`,
		rideID, staffID, reason)
	if err != nil {
		return fmt.Errorf("cancel ride: %w", err)
	}
	return nil
}

func (r *AdminRepository) ListPricingRules(ctx context.Context, serviceAreaID *string) ([]ports.PricingRule, error) {
	if r.db == nil {
		return nil, errors.New("admin repository: nil database")
	}
	query := `SELECT id::text, service_area_id::text, vehicle_type_id::text, version, mode,
		currency_code, base_fare, per_km, per_minute, minimum_fare, commission_bps,
		rounding_step, status, created_at FROM pricing_rules`
	args := []interface{}{}
	if serviceAreaID != nil {
		query += " WHERE service_area_id = $1"
		args = append(args, *serviceAreaID)
	}
	query += " ORDER BY service_area_id, version DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list pricing rules: %w", err)
	}
	defer rows.Close()

	var rules []ports.PricingRule
	for rows.Next() {
		var rule ports.PricingRule
		if err := rows.Scan(&rule.ID, &rule.ServiceAreaID, &rule.VehicleTypeID, &rule.Version, &rule.Mode,
			&rule.CurrencyCode, &rule.BaseFare, &rule.PerKm, &rule.PerMinute, &rule.MinimumFare,
			&rule.CommissionBps, &rule.RoundingStep, &rule.Status, &rule.CreatedAt); err != nil {
			return nil, err
		}
		rules = append(rules, rule)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return rules, nil
}

func (r *AdminRepository) ListPayouts(ctx context.Context, status *string, limit int, offset int) ([]ports.AdminPayout, error) {
	if r.db == nil {
		return nil, errors.New("admin repository: nil database")
	}
	query := `SELECT id::text, driver_id::text, direction, amount, currency_code, status,
		requested_by, reviewed_by::text, created_at, updated_at FROM driver_payouts`
	args := []interface{}{}
	argIdx := 1
	if status != nil {
		query += " WHERE status = $" + argNum(argIdx)
		args = append(args, *status)
		argIdx++
	}
	query += " ORDER BY created_at DESC LIMIT $" + argNum(argIdx)
	args = append(args, limit)
	argIdx++
	query += " OFFSET $" + argNum(argIdx)
	args = append(args, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list payouts: %w", err)
	}
	defer rows.Close()

	var payouts []ports.AdminPayout
	for rows.Next() {
		var p ports.AdminPayout
		var reviewedBy sql.NullString
		if err := rows.Scan(&p.ID, &p.DriverID, &p.Direction, &p.AmountMinor, &p.CurrencyCode, &p.Status,
			&p.RequestedBy, &reviewedBy, &p.CreatedAt, &p.CreatedAt); err != nil {
			return nil, err
		}
		if reviewedBy.Valid {
			p.ReviewedBy = strPtr(reviewedBy.String)
		}
		payouts = append(payouts, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return payouts, nil
}

func (r *AdminRepository) ApprovePayout(ctx context.Context, payoutID, reviewerID string) error {
	if r.db == nil {
		return errors.New("admin repository: nil database")
	}
	_, err := r.db.Exec(ctx, `
		UPDATE driver_payouts SET status = 'APPROVED', reviewed_by = $2::uuid, reviewed_at = now(), updated_at = now()
		WHERE id = $1::uuid AND requested_by <> $2::uuid AND status = 'PENDING'`, payoutID, reviewerID)
	if err != nil {
		return fmt.Errorf("approve payout: %w", err)
	}
	return nil
}

func (r *AdminRepository) DriverBalances(ctx context.Context) ([]ports.DriverBalance, error) {
	if r.db == nil {
		return nil, errors.New("admin repository: nil database")
	}
	rows, err := r.db.Query(ctx, `
		SELECT driver_id::text, currency_code, balance, entry_count,
			to_char(last_entry_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
		FROM driver_balances ORDER BY driver_id`)
	if err != nil {
		return nil, fmt.Errorf("driver balances: %w", err)
	}
	defer rows.Close()

	var balances []ports.DriverBalance
	for rows.Next() {
		var b ports.DriverBalance
		var lastEntryAt sql.NullString
		if err := rows.Scan(&b.DriverID, &b.CurrencyCode, &b.Balance, &b.EntryCount, &lastEntryAt); err != nil {
			return nil, err
		}
		if lastEntryAt.Valid {
			b.LastEntryAt = lastEntryAt.String
		}
		balances = append(balances, b)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return balances, nil
}

func (r *AdminRepository) Stats(ctx context.Context) (*ports.AdminStats, error) {
	if r.db == nil {
		return nil, errors.New("admin repository: nil database")
	}
	stats := &ports.AdminStats{TripsByStatus: make(map[string]int)}

	// Trips by status
	rows, err := r.db.Query(ctx, `SELECT status, count(*) FROM rides GROUP BY status`)
	if err != nil {
		return nil, fmt.Errorf("trips stats: %w", err)
	}
	totalRides := 0
	for rows.Next() {
		var status string
		var count int
		if err := rows.Scan(&status, &count); err != nil {
			rows.Close()
			return nil, err
		}
		stats.TripsByStatus[status] = count
		totalRides += count
	}
	rows.Close()
	stats.TotalRides = totalRides

	// Online drivers
	err = r.db.QueryRow(ctx, `SELECT count(*) FROM driver_profiles WHERE is_online = true`).Scan(&stats.OnlineDrivers)
	if err != nil {
		return nil, fmt.Errorf("online drivers stats: %w", err)
	}

	// Total paid out
	var totalPaidOut sql.NullFloat64
	err = r.db.QueryRow(ctx, `SELECT COALESCE(sum(amount), 0) FROM driver_payouts WHERE status = 'APPROVED'`).Scan(&totalPaidOut)
	if err != nil {
		return nil, fmt.Errorf("paid out stats: %w", err)
	}
	if totalPaidOut.Valid {
		stats.TotalPaidOutMinor = totalPaidOut.Float64
	}

	return stats, nil
}

func argNum(n int) string { return fmt.Sprintf("$%d", n) }

func strPtr(s string) *string { return &s }
