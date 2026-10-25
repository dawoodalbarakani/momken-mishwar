package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

type fakeRefreshRepository struct {
	byHash map[string]domain.RefreshToken
}

func newFakeRefreshRepository() *fakeRefreshRepository {
	return &fakeRefreshRepository{byHash: make(map[string]domain.RefreshToken)}
}

func (r *fakeRefreshRepository) Create(_ context.Context, token domain.RefreshToken) error {
	if _, exists := r.byHash[token.TokenHash]; exists { return errors.New("duplicate hash") }
	r.byHash[token.TokenHash] = token
	return nil
}

func (r *fakeRefreshRepository) Rotate(_ context.Context, oldHash string, replacement domain.RefreshToken, now time.Time) (string, string, error) {
	old, ok := r.byHash[oldHash]
	if !ok { return "", "", domain.ErrRefreshTokenInvalid }
	if old.RotatedAt != nil || old.RevokedAt != nil {
		for hash, token := range r.byHash {
			if token.FamilyID == old.FamilyID {
				token.RevokedAt = &now
				reason := "REUSE_DETECTED"
				token.RevokedReason = &reason
				r.byHash[hash] = token
			}
		}
		return "", "", domain.ErrRefreshTokenReuse
	}
	if !old.ExpiresAt.After(now) { return "", "", domain.ErrRefreshTokenExpired }
	old.RotatedAt = &now
	r.byHash[oldHash] = old
	replacement.UserID = old.UserID
	replacement.FamilyID = old.FamilyID
	if err := replacement.Validate(); err != nil { return "", "", err }
	r.byHash[replacement.TokenHash] = replacement
	return old.UserID, old.FamilyID, nil
}

func (r *fakeRefreshRepository) RevokeByHash(_ context.Context, tokenHash, reason string, now time.Time) error {
	token, ok := r.byHash[tokenHash]
	if !ok { return domain.ErrRefreshTokenInvalid }
	return r.RevokeFamily(context.Background(), token.FamilyID, reason, now)
}

func (r *fakeRefreshRepository) RevokeFamily(_ context.Context, familyID, reason string, now time.Time) error {
	for hash, token := range r.byHash {
		if token.FamilyID == familyID {
			token.RevokedAt = &now
			token.RevokedReason = &reason
			r.byHash[hash] = token
		}
	}
	return nil
}

func TestRefreshTokenServiceStoresOnlyHashAndRotates(t *testing.T) {
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	repo := newFakeRefreshRepository()
	svc, err := NewRefreshTokenService(RefreshTokenServiceConfig{
		Repository: repo, TTL: 24 * time.Hour, Now: func() time.Time { return now },
	})
	if err != nil { t.Fatal(err) }

	first, err := svc.Create(context.Background(), "user-123", nil)
	if err != nil { t.Fatal(err) }
	if first.RefreshToken == "" || first.FamilyID == "" { t.Fatal("expected opaque refresh token and family ID") }
	if _, ok := repo.byHash[first.RefreshToken]; ok { t.Fatal("raw refresh token must not be persisted") }
	if _, ok := repo.byHash[hashRefreshSecret(first.RefreshToken)]; !ok { t.Fatal("expected token digest in repository") }

	second, userID, err := svc.Rotate(context.Background(), first.RefreshToken, nil)
	if err != nil { t.Fatal(err) }
	if userID != "user-123" { t.Fatalf("user ID = %q, want user-123", userID) }
	if second.RefreshToken == "" || second.RefreshToken == first.RefreshToken { t.Fatal("expected a new refresh token") }
	if second.FamilyID != first.FamilyID { t.Fatal("rotation must retain the family ID") }

	_, _, err = svc.Rotate(context.Background(), first.RefreshToken, nil)
	if !errors.Is(err, domain.ErrRefreshTokenReuse) { t.Fatalf("reuse error = %v, want ErrRefreshTokenReuse", err) }
	for _, token := range repo.byHash {
		if token.FamilyID == first.FamilyID && token.RevokedAt == nil {
			t.Fatal("all tokens in reused family should be revoked")
		}
	}
}
