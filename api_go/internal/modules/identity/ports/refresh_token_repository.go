package ports

import (
	"context"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

type RefreshTokenRepository interface {
	Create(ctx context.Context, token domain.RefreshToken) error
	// Rotate atomically consumes oldHash and inserts replacement in the same family.
	// A reused rotated token revokes its entire family before returning ErrRefreshTokenReuse.
	Rotate(ctx context.Context, oldHash string, replacement domain.RefreshToken, now time.Time) (userID, familyID string, err error)
	RevokeFamily(ctx context.Context, familyID, reason string, now time.Time) error
	RevokeByHash(ctx context.Context, tokenHash, reason string, now time.Time) error
}
