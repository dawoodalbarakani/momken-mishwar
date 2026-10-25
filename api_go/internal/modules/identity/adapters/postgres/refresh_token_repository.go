package postgres

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/ports"
)

type RefreshTokenRepository struct { db *pgxpool.Pool }

func NewRefreshTokenRepository(db *pgxpool.Pool) *RefreshTokenRepository {
	return &RefreshTokenRepository{db: db}
}

func (r *RefreshTokenRepository) Create(ctx context.Context, token domain.RefreshToken) error {
	if r.db == nil { return errors.New("identity refresh token repository: nil database") }
	if err := token.Validate(); err != nil { return err }
	_, err := r.db.Exec(ctx, `
		INSERT INTO refresh_tokens (id, user_id, family_id, token_hash, device_id, expires_at, created_at)
		VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7)`,
		token.ID, token.UserID, token.FamilyID, token.TokenHash, token.DeviceID, token.ExpiresAt, token.CreatedAt)
	if err != nil { return fmt.Errorf("insert refresh token: %w", err) }
	return nil
}

func (r *RefreshTokenRepository) Rotate(ctx context.Context, oldHash string, replacement domain.RefreshToken, now time.Time) (string, error) {
	if r.db == nil { return "", errors.New("identity refresh token repository: nil database") }
	if oldHash == "" { return "", domain.ErrRefreshTokenInvalid }
	tx, err := r.db.Begin(ctx)
	if err != nil { return "", fmt.Errorf("begin refresh rotation: %w", err) }
	defer func() { _ = tx.Rollback(ctx) }()

	var userID, familyID string
	var expiresAt time.Time
	var rotatedAt, revokedAt *time.Time
	err = tx.QueryRow(ctx, `
		SELECT user_id::text, family_id::text, expires_at, rotated_at, revoked_at
		FROM refresh_tokens WHERE token_hash = $1 FOR UPDATE`, oldHash).
		Scan(&userID, &familyID, &expiresAt, &rotatedAt, &revokedAt)
	if errors.Is(err, pgx.ErrNoRows) { return "", domain.ErrRefreshTokenInvalid }
	if err != nil { return "", fmt.Errorf("load refresh token: %w", err) }

	if rotatedAt != nil || revokedAt != nil {
		_, err = tx.Exec(ctx, `UPDATE refresh_tokens
			SET revoked_at = COALESCE(revoked_at, $2), revoked_reason = COALESCE(revoked_reason, 'REUSE_DETECTED')
			WHERE family_id = $1::uuid`, familyID, now)
		if err != nil { return "", fmt.Errorf("revoke reused refresh family: %w", err) }
		if err := tx.Commit(ctx); err != nil { return "", fmt.Errorf("commit reuse response: %w", err) }
		return "", domain.ErrRefreshTokenReuse
	}
	if !expiresAt.After(now) {
		return "", domain.ErrRefreshTokenExpired
	}
	replacement.UserID = userID
	replacement.FamilyID = familyID
	if err := replacement.Validate(); err != nil { return "", err }
	_, err = tx.Exec(ctx, `UPDATE refresh_tokens SET rotated_at = $2 WHERE token_hash = $1 AND rotated_at IS NULL AND revoked_at IS NULL`, oldHash, now)
	if err != nil { return "", fmt.Errorf("mark refresh token rotated: %w", err) }
	_, err = tx.Exec(ctx, `
		INSERT INTO refresh_tokens (id, user_id, family_id, token_hash, device_id, expires_at, created_at)
		VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7)`,
		replacement.ID, replacement.UserID, replacement.FamilyID, replacement.TokenHash,
		replacement.DeviceID, replacement.ExpiresAt, replacement.CreatedAt)
	if err != nil { return "", fmt.Errorf("insert rotated refresh token: %w", err) }
	if err := tx.Commit(ctx); err != nil { return "", fmt.Errorf("commit refresh rotation: %w", err) }
	return userID, nil
}

func (r *RefreshTokenRepository) RevokeFamily(ctx context.Context, familyID, reason string, now time.Time) error {
	if r.db == nil { return errors.New("identity refresh token repository: nil database") }
	if familyID == "" || reason == "" { return errors.New("family ID and revocation reason are required") }
	_, err := r.db.Exec(ctx, `UPDATE refresh_tokens
		SET revoked_at = COALESCE(revoked_at, $2), revoked_reason = COALESCE(revoked_reason, $3)
		WHERE family_id = $1::uuid`, familyID, now, reason)
	if err != nil { return fmt.Errorf("revoke refresh token family: %w", err) }
	return nil
}

// Keep the interface relationship checked by the compiler.
var _ ports.RefreshTokenRepository = (*RefreshTokenRepository)(nil)
