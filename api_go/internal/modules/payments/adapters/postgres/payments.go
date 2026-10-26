package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/payments/ports"
)

type PaymentRepository struct {
	db *pgxpool.Pool
}

func NewPaymentRepository(db *pgxpool.Pool) *PaymentRepository {
	return &PaymentRepository{db: db}
}

func (r *PaymentRepository) Create(ctx context.Context, record ports.PaymentRecord) (ports.PaymentRecord, error) {
	if r.db == nil {
		return ports.PaymentRecord{}, errors.New("payment repository: nil database")
	}
	var p ports.PaymentRecord
	err := r.db.QueryRow(ctx, `
		INSERT INTO payment_records (ride_id, method, status, amount, currency_code)
		VALUES ($1::uuid, $2, 'PENDING', $3, $4)
		RETURNING id::text, ride_id::text, method, status, amount, currency_code,
		          provider, provider_reference, collected_at, reconciled_by, reconciled_at, created_at, updated_at`,
		record.RideID, record.Method, record.AmountMinor, record.CurrencyCode).Scan(
		&p.ID, &p.RideID, &p.Method, &p.Status, &p.AmountMinor, &p.CurrencyCode,
		&p.Provider, &p.ProviderReference, &p.CollectedAt, &p.ReconciledBy, &p.ReconciledAt, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return ports.PaymentRecord{}, fmt.Errorf("create payment: %w", err)
	}
	return p, nil
}

func (r *PaymentRepository) List(ctx context.Context, status *string, limit int, offset int) ([]ports.PaymentRecord, error) {
	if r.db == nil {
		return nil, errors.New("payment repository: nil database")
	}
	query := `SELECT id::text, ride_id::text, method, status, amount, currency_code,
		provider, provider_reference, collected_at, reconciled_by, reconciled_at, created_at, updated_at
		FROM payment_records`
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
		return nil, fmt.Errorf("list payments: %w", err)
	}
	defer rows.Close()

	var records []ports.PaymentRecord
	for rows.Next() {
		var p ports.PaymentRecord
		var provider, providerRef, collectedAt, reconciledBy, reconciledAt sql.NullString
		if err := rows.Scan(&p.ID, &p.RideID, &p.Method, &p.Status, &p.AmountMinor, &p.CurrencyCode,
			&provider, &providerRef, &collectedAt, &reconciledBy, &reconciledAt, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		if provider.Valid {
			p.Provider = strPtr(provider.String)
		}
		if providerRef.Valid {
			p.ProviderReference = strPtr(providerRef.String)
		}
		if collectedAt.Valid {
			p.CollectedAt = strPtr(collectedAt.String)
		}
		if reconciledBy.Valid {
			p.ReconciledBy = strPtr(reconciledBy.String)
		}
		if reconciledAt.Valid {
			p.ReconciledAt = strPtr(reconciledAt.String)
		}
		records = append(records, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return records, nil
}

func (r *PaymentRepository) FindByRide(ctx context.Context, rideID string) (ports.PaymentRecord, bool, error) {
	if r.db == nil {
		return ports.PaymentRecord{}, false, errors.New("payment repository: nil database")
	}
	var p ports.PaymentRecord
	err := r.db.QueryRow(ctx, `
		SELECT id::text, ride_id::text, method, status, amount, currency_code,
		       provider, provider_reference, collected_at, reconciled_by, reconciled_at, created_at, updated_at
		FROM payment_records WHERE ride_id = $1::uuid`, rideID).Scan(
		&p.ID, &p.RideID, &p.Method, &p.Status, &p.AmountMinor, &p.CurrencyCode,
		&p.Provider, &p.ProviderReference, &p.CollectedAt, &p.ReconciledBy, &p.ReconciledAt, &p.CreatedAt, &p.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return ports.PaymentRecord{}, false, nil
	}
	if err != nil {
		return ports.PaymentRecord{}, false, fmt.Errorf("find payment by ride: %w", err)
	}
	return p, true, nil
}

func (r *PaymentRepository) UpdateStatus(ctx context.Context, id string, status string, collectedAt *string, reconciledBy *string) (ports.PaymentRecord, error) {
	if r.db == nil {
		return ports.PaymentRecord{}, errors.New("payment repository: nil database")
	}
	var p ports.PaymentRecord
	err := r.db.QueryRow(ctx, `
		UPDATE payment_records SET status = $2,
			collected_at = CASE WHEN $2 IN ('COLLECTED_BY_DRIVER','RECONCILED') THEN now() ELSE collected_at END,
			reconciled_by = $3, reconciled_at = CASE WHEN $2 = 'RECONCILED' THEN now() ELSE reconciled_at END,
			updated_at = now()
		WHERE id = $1::uuid
		RETURNING id::text, ride_id::text, method, status, amount, currency_code,
		          provider, provider_reference, collected_at, reconciled_by, reconciled_at, created_at, updated_at`,
		id, status, reconciledBy).Scan(
		&p.ID, &p.RideID, &p.Method, &p.Status, &p.AmountMinor, &p.CurrencyCode,
		&p.Provider, &p.ProviderReference, &p.CollectedAt, &p.ReconciledBy, &p.ReconciledAt, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return ports.PaymentRecord{}, fmt.Errorf("update payment status: %w", err)
	}
	return p, nil
}

type PayoutRepository struct {
	db *pgxpool.Pool
}

func NewPayoutRepository(db *pgxpool.Pool) *PayoutRepository {
	return &PayoutRepository{db: db}
}

func (r *PayoutRepository) Create(ctx context.Context, payout ports.DriverPayout) (ports.DriverPayout, error) {
	if r.db == nil {
		return ports.DriverPayout{}, errors.New("payout repository: nil database")
	}
	var p ports.DriverPayout
	err := r.db.QueryRow(ctx, `
		INSERT INTO driver_payouts (driver_id, direction, amount, currency_code, status, method, reference, note, requested_by)
		VALUES ($1::uuid, $2, $3, $4, 'PENDING', $5, $6, $7, $8)
		RETURNING id::text, driver_id::text, direction, amount, currency_code, status,
		          method, reference, note, requested_by, reviewed_by, reviewed_at, created_at, updated_at`,
		payout.DriverID, payout.Direction, payout.AmountMinor, payout.CurrencyCode,
		nullStrPtr(payout.Method), nullStrPtr(payout.Reference), nullStrPtr(payout.Note), payout.RequestedBy,
	).Scan(
		&p.ID, &p.DriverID, &p.Direction, &p.AmountMinor, &p.CurrencyCode, &p.Status,
		&p.Method, &p.Reference, &p.Note, &p.RequestedBy, &p.ReviewedBy, &p.ReviewedAt, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return ports.DriverPayout{}, fmt.Errorf("create payout: %w", err)
	}
	return p, nil
}

func (r *PayoutRepository) List(ctx context.Context, status *string, limit int, offset int) ([]ports.DriverPayout, error) {
	if r.db == nil {
		return nil, errors.New("payout repository: nil database")
	}
	query := `SELECT id::text, driver_id::text, direction, amount, currency_code, status,
		method, reference, note, requested_by, reviewed_by, reviewed_at, created_at, updated_at
		FROM driver_payouts`
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

	var payouts []ports.DriverPayout
	for rows.Next() {
		var p ports.DriverPayout
		if err := rows.Scan(&p.ID, &p.DriverID, &p.Direction, &p.AmountMinor, &p.CurrencyCode, &p.Status,
			&p.Method, &p.Reference, &p.Note, &p.RequestedBy, &p.ReviewedBy, &p.ReviewedAt, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		payouts = append(payouts, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return payouts, nil
}

func (r *PayoutRepository) FindByID(ctx context.Context, id string) (ports.DriverPayout, bool, error) {
	if r.db == nil {
		return ports.DriverPayout{}, false, errors.New("payout repository: nil database")
	}
	var p ports.DriverPayout
	err := r.db.QueryRow(ctx, `
		SELECT id::text, driver_id::text, direction, amount, currency_code, status,
			method, reference, note, requested_by, reviewed_by, reviewed_at, created_at, updated_at
		FROM driver_payouts WHERE id = $1::uuid`, id).Scan(
		&p.ID, &p.DriverID, &p.Direction, &p.AmountMinor, &p.CurrencyCode, &p.Status,
		&p.Method, &p.Reference, &p.Note, &p.RequestedBy, &p.ReviewedBy, &p.ReviewedAt, &p.CreatedAt, &p.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return ports.DriverPayout{}, false, nil
	}
	if err != nil {
		return ports.DriverPayout{}, false, fmt.Errorf("find payout: %w", err)
	}
	return p, true, nil
}

func (r *PayoutRepository) Approve(ctx context.Context, id string, reviewerID string) (ports.DriverPayout, error) {
	if r.db == nil {
		return ports.DriverPayout{}, errors.New("payout repository: nil database")
	}
	var p ports.DriverPayout
	err := r.db.QueryRow(ctx, `
		UPDATE driver_payouts SET status = 'APPROVED', reviewed_by = $2::uuid, reviewed_at = now(), updated_at = now()
		WHERE id = $1::uuid
		RETURNING id::text, driver_id::text, direction, amount, currency_code, status,
			method, reference, note, requested_by, reviewed_by, reviewed_at, created_at, updated_at`,
		id, reviewerID).Scan(
		&p.ID, &p.DriverID, &p.Direction, &p.AmountMinor, &p.CurrencyCode, &p.Status,
		&p.Method, &p.Reference, &p.Note, &p.RequestedBy, &p.ReviewedBy, &p.ReviewedAt, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		return ports.DriverPayout{}, fmt.Errorf("approve payout: %w", err)
	}
	return p, nil
}

type LedgerRepository struct {
	db *pgxpool.Pool
}

func NewLedgerRepository(db *pgxpool.Pool) *LedgerRepository {
	return &LedgerRepository{db: db}
}

func (r *LedgerRepository) Create(ctx context.Context, entry ports.DriverLedgerEntry) (ports.DriverLedgerEntry, error) {
	if r.db == nil {
		return ports.DriverLedgerEntry{}, errors.New("ledger repository: nil database")
	}
	var e ports.DriverLedgerEntry
	err := r.db.QueryRow(ctx, `
		INSERT INTO driver_ledger_entries (driver_id, ride_id, payout_id, entry_type, amount, currency_code, idempotency_key, memo)
		VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7, $8)
		RETURNING id::text, driver_id::text, ride_id::text, payout_id::text, entry_type, amount, currency_code,
		          idempotency_key, memo, created_by, created_at`,
		entry.DriverID, nullUUID(entry.RideID), nullUUID(entry.PayoutID), entry.EntryType, entry.AmountMinor,
		entry.CurrencyCode, entry.IdempotencyKey, nullStrPtr(entry.Memo),
	).Scan(
		&e.ID, &e.DriverID, &e.RideID, &e.PayoutID, &e.EntryType, &e.AmountMinor, &e.CurrencyCode,
		&e.IdempotencyKey, &e.Memo, &e.CreatedBy, &e.CreatedAt,
	)
	if err != nil {
		return ports.DriverLedgerEntry{}, fmt.Errorf("create ledger entry: %w", err)
	}
	return e, nil
}

func (r *LedgerRepository) ListByDriver(ctx context.Context, driverID string, currency *string, limit int, offset int) ([]ports.DriverLedgerEntry, error) {
	if r.db == nil {
		return nil, errors.New("ledger repository: nil database")
	}
	query := `SELECT id::text, driver_id::text, ride_id::text, payout_id::text, entry_type, amount, currency_code,
		idempotency_key, memo, created_by, created_at FROM driver_ledger_entries WHERE driver_id = $1::uuid`
	args := []interface{}{driverID}
	argIdx := 2
	if currency != nil {
		query += " AND currency_code = $" + argNum(argIdx)
		args = append(args, *currency)
		argIdx++
	}
	query += " ORDER BY created_at DESC LIMIT $" + argNum(argIdx)
	args = append(args, limit)
	argIdx++
	query += " OFFSET $" + argNum(argIdx)
	args = append(args, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list ledger entries: %w", err)
	}
	defer rows.Close()

	var entries []ports.DriverLedgerEntry
	for rows.Next() {
		var e ports.DriverLedgerEntry
		if err := rows.Scan(&e.ID, &e.DriverID, &e.RideID, &e.PayoutID, &e.EntryType, &e.AmountMinor, &e.CurrencyCode,
			&e.IdempotencyKey, &e.Memo, &e.CreatedBy, &e.CreatedAt); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return entries, nil
}

func (r *LedgerRepository) Balance(ctx context.Context, driverID string, currency string) (int64, error) {
	if r.db == nil {
		return 0, errors.New("ledger repository: nil database")
	}
	var balance int64
	err := r.db.QueryRow(ctx, `SELECT COALESCE(SUM(amount), 0) FROM driver_ledger_entries WHERE driver_id = $1::uuid AND currency_code = $2`, driverID, currency).Scan(&balance)
	if err != nil {
		return 0, fmt.Errorf("ledger balance: %w", err)
	}
	return balance, nil
}

func (r *LedgerRepository) SettleCashRide(ctx context.Context, rideID, driverID, currency string, grossMinor, commissionMinor, driverNetMinor int64, idempotencyKey string) error {
	if r.db == nil {
		return errors.New("ledger repository: nil database")
	}
	_, err := r.db.Exec(ctx, `
		WITH ins AS (
			INSERT INTO driver_ledger_entries (driver_id, ride_id, entry_type, amount, currency_code, idempotency_key)
			VALUES ($1::uuid, $2::uuid, 'EARNING', $3, $4, $5)
			ON CONFLICT (idempotency_key) DO NOTHING
			RETURNING 1
		),
		ins2 AS (
			INSERT INTO driver_ledger_entries (driver_id, ride_id, entry_type, amount, currency_code, idempotency_key)
			VALUES ($1::uuid, $2::uuid, 'CASH_COLLECTED', -$3, $4, $6)
			ON CONFLICT (idempotency_key) DO NOTHING
			RETURNING 1
		)
		SELECT 1`, driverID, rideID, driverNetMinor, currency, idempotencyKey+":EARNING", idempotencyKey+":CASH_COLLECTED")
	if err != nil {
		return fmt.Errorf("settle cash ride: %w", err)
	}
	return nil
}

func nullUUID(s *string) interface{} {
	if s == nil || *s == "" {
		return nil
	}
	return *s
}

func argNum(n int) string { return fmt.Sprintf("$%d", n) }

func strPtr(s string) *string { return &s }

func nullStrPtr(s *string) interface{} {
	if s == nil {
		return nil
	}
	return *s
}

var _ = time.Time{}
