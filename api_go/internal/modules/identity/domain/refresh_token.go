package domain

import (
	"errors"
	"time"
)

var (
	ErrRefreshTokenInvalid = errors.New("refresh token is invalid")
	ErrRefreshTokenExpired = errors.New("refresh token is expired")
	ErrRefreshTokenReuse   = errors.New("refresh token reuse detected")
)

type RefreshToken struct {
	ID            string
	UserID        string
	FamilyID      string
	TokenHash     string
	DeviceID      *string
	ExpiresAt     time.Time
	RotatedAt     *time.Time
	RevokedAt     *time.Time
	RevokedReason *string
	CreatedAt     time.Time
}

func (t RefreshToken) Validate() error {
	if t.ID == "" || t.UserID == "" || t.FamilyID == "" || t.TokenHash == "" ||
		t.ExpiresAt.IsZero() || t.CreatedAt.IsZero() || !t.ExpiresAt.After(t.CreatedAt) {
		return errors.New("invalid refresh token")
	}
	return nil
}
