package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
)

func TestRequireAccessToken(t *testing.T) {
	now := time.Date(2026, 10, 25, 12, 0, 0, 0, time.UTC)
	tokens, err := service.NewAccessTokenService(service.AccessTokenConfig{
		SigningKey: []byte("01234567890123456789012345678901"),
		Issuer: "api_go", Audience: "mishwar-apps", TTL: time.Minute,
		Now: func() time.Time { return now },
	})
	if err != nil { t.Fatal(err) }
	phone := "+967771234567"
	jwt, _, err := tokens.Issue(domain.User{
		ID: "user-123", PhoneE164: &phone, Locale: "ar", Status: domain.UserActive,
		Roles: []domain.Role{domain.RoleCustomer}, CreatedAt: now, UpdatedAt: now,
	})
	if err != nil { t.Fatal(err) }

	protected := RequireAccessToken(tokens, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := AccessTokenClaimsFromContext(r.Context())
		if !ok || claims.Subject != "user-123" { t.Errorf("expected verified claims in context: %+v", claims) }
		w.WriteHeader(http.StatusNoContent)
	}))

	t.Run("missing token rejected", func(t *testing.T) {
		rec := httptest.NewRecorder()
		protected.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/protected", nil))
		if rec.Code != http.StatusUnauthorized { t.Fatalf("status = %d, want 401", rec.Code) }
	})
	t.Run("valid token accepted", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/protected", nil)
		req.Header.Set("Authorization", "Bearer "+jwt)
		rec := httptest.NewRecorder()
		protected.ServeHTTP(rec, req)
		if rec.Code != http.StatusNoContent { t.Fatalf("status = %d, want 204", rec.Code) }
	})
}
