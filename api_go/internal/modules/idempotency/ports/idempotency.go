package ports

import (
	"context"
	"time"
)

const (
	StateInProgress = "IN_PROGRESS"
	StateCompleted  = "COMPLETED"
)

// IdempotencyStore manages idempotency keys for write operations.
type IdempotencyStore interface {
	Check(ctx context.Context, userID, scope, idempotencyKey, requestHash string) ([]byte, bool, error)
	Record(ctx context.Context, userID, scope, idempotencyKey, requestHash string, responseStatus int, responseBody []byte, resourceID *string, expiresAt time.Time) error
}

var ErrIdempotencyConflict = idempotencyConflictError{}

type idempotencyConflictError struct{}

func (idempotencyConflictError) Error() string {
	return "idempotency key was already used with a different request"
}
