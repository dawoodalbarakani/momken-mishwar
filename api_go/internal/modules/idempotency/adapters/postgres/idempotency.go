package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/idempotency/ports"
)

type IdempotencyStore struct {
	db *pgxpool.Pool
}

func NewIdempotencyStore(db *pgxpool.Pool) *IdempotencyStore {
	return &IdempotencyStore{db: db}
}

// Check looks up an idempotency key. It returns (nil, false, nil) when the key
// does not exist, (body, true, nil) when it exists and matches the request hash,
// and (nil, false, ErrIdempotencyConflict) when the same key was used with a
// different body or is still in progress.
func (s *IdempotencyStore) Check(ctx context.Context, userID, scope, idempotencyKey, requestHash string) ([]byte, bool, error) {
	if s.db == nil {
		return nil, false, errors.New("idempotency store: nil database")
	}
	var responseBody []byte
	var state, storedHash string
	err := s.db.QueryRow(ctx, `
		SELECT response_body, state, request_hash
		FROM idempotency_keys
		WHERE user_id = $1::uuid AND scope = $2 AND idempotency_key = $3
	`, userID, scope, idempotencyKey).Scan(&responseBody, &state, &storedHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("check idempotency key: %w", err)
	}
	if state != ports.StateCompleted {
		return nil, false, ports.ErrIdempotencyConflict
	}
	if storedHash != requestHash {
		return nil, false, ports.ErrIdempotencyConflict
	}
	return responseBody, true, nil
}

// Record stores a completed idempotency entry.
func (s *IdempotencyStore) Record(ctx context.Context, userID, scope, idempotencyKey, requestHash string, responseStatus int, responseBody []byte, resourceID *string, expiresAt time.Time) error {
	if s.db == nil {
		return errors.New("idempotency store: nil database")
	}
	var resourceIDArg interface{}
	if resourceID != nil {
		resourceIDArg = *resourceID
	}
	_, err := s.db.Exec(ctx, `
		INSERT INTO idempotency_keys (user_id, scope, idempotency_key, request_hash, state, response_status, response_body, resource_id, expires_at)
		VALUES ($1::uuid, $2, $3, $4, 'COMPLETED', $5, $6::jsonb, $7::uuid, $8)
		ON CONFLICT (user_id, scope, idempotency_key) DO NOTHING`,
		userID, scope, idempotencyKey, requestHash, responseStatus, responseBody, resourceIDArg, expiresAt)
	if err != nil {
		return fmt.Errorf("record idempotency key: %w", err)
	}
	return nil
}
