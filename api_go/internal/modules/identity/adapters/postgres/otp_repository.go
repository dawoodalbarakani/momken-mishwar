package postgres

import (
	"context"
	"crypto/subtle"
	"errors"
	"fmt"
	"net"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/ports"
)

type OTPRepository struct {
	db *pgxpool.Pool
}

func NewOTPRepository(db *pgxpool.Pool) *OTPRepository {
	return &OTPRepository{db: db}
}

func (r *OTPRepository) Create(ctx context.Context, challenge domain.OTPChallenge, requestedIP *string) error {
	if r.db == nil {
		return errors.New("identity OTP repository: nil database")
	}
	if err := challenge.Validate(); err != nil {
		return err
	}
	var ip any
	if requestedIP != nil {
		parsed := net.ParseIP(*requestedIP)
		if parsed == nil {
			return errors.New("identity OTP repository: invalid requested IP")
		}
		ip = parsed.String()
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO otp_challenges
			(id, phone_e164, purpose, code_hash, attempts, max_attempts, expires_at, consumed_at, requested_ip, created_at)
		VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9::inet, $10)`,
		challenge.ID, challenge.PhoneE164, string(challenge.Purpose), challenge.CodeHash,
		challenge.Attempts, challenge.MaxAttempts, challenge.ExpiresAt, challenge.ConsumedAt, ip, challenge.CreatedAt)
	if err != nil {
		return fmt.Errorf("insert OTP challenge: %w", err)
	}
	return nil
}

// VerifyAndConsume locks the latest challenge, persists every eligible attempt,
// and consumes a valid code in the same transaction. The caller must pass a
// cryptographic hash of the submitted code, never the plaintext code.
func (r *OTPRepository) VerifyAndConsume(ctx context.Context, phoneE164 string, purpose domain.OTPPurpose, candidateHash string, now time.Time) (domain.OTPChallenge, error) {
	if r.db == nil {
		return domain.OTPChallenge{}, errors.New("identity OTP repository: nil database")
	}
	if phoneE164 == "" || candidateHash == "" {
		return domain.OTPChallenge{}, domain.ErrInvalidOTPChallenge
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return domain.OTPChallenge{}, fmt.Errorf("begin OTP verification: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var c domain.OTPChallenge
	var purposeValue string
	var consumedAt *time.Time
	err = tx.QueryRow(ctx, `
		SELECT id::text, phone_e164, purpose, code_hash, attempts, max_attempts,
		       expires_at, consumed_at, created_at
		FROM otp_challenges
		WHERE phone_e164 = $1 AND purpose = $2
		ORDER BY created_at DESC, id DESC
		LIMIT 1
		FOR UPDATE`, phoneE164, string(purpose)).Scan(
		&c.ID, &c.PhoneE164, &purposeValue, &c.CodeHash, &c.Attempts,
		&c.MaxAttempts, &c.ExpiresAt, &consumedAt, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.OTPChallenge{}, ports.ErrOTPNotFound
	}
	if err != nil {
		return domain.OTPChallenge{}, fmt.Errorf("load OTP challenge: %w", err)
	}
	c.Purpose = domain.OTPPurpose(purposeValue)
	c.ConsumedAt = consumedAt
	if err := c.CanAttempt(now); err != nil {
		return domain.OTPChallenge{}, err
	}

	// Increment while holding the row lock. A mismatch is committed below, so
	// concurrent guesses cannot bypass the database attempt limit.
	c.Attempts++
	_, err = tx.Exec(ctx, "UPDATE otp_challenges SET attempts = $2 WHERE id = $1::uuid", c.ID, c.Attempts)
	if err != nil {
		return domain.OTPChallenge{}, fmt.Errorf("increment OTP attempts: %w", err)
	}

	matches := subtle.ConstantTimeCompare([]byte(c.CodeHash), []byte(candidateHash)) == 1
	if matches {
		c.ConsumedAt = &now
		_, err = tx.Exec(ctx, "UPDATE otp_challenges SET consumed_at = $2 WHERE id = $1::uuid AND consumed_at IS NULL", c.ID, now)
		if err != nil {
			return domain.OTPChallenge{}, fmt.Errorf("consume OTP challenge: %w", err)
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.OTPChallenge{}, fmt.Errorf("commit OTP verification: %w", err)
	}
	if !matches {
		return domain.OTPChallenge{}, ports.ErrOTPCodeMismatch
	}
	return c, nil
}
