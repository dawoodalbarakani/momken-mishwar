package httpapi

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
)

func TestRequireAnyRole(t *testing.T) {
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

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusNoContent) })
	req := httptest.NewRequest(http.MethodGet, "/admin", nil)
	req.Header.Set("Authorization", "Bearer "+jwt)

	adminOnly := RequireAccessToken(tokens, RequireAnyRole(domain.RoleAdmin)(handler))
	rec := httptest.NewRecorder()
	adminOnly.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden { t.Fatalf("customer accessing admin route: got %d, want 403", rec.Code) }

	customerAllowed := RequireAccessToken(tokens, RequireAnyRole(domain.RoleCustomer)(handler))
	rec = httptest.NewRecorder()
	customerAllowed.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent { t.Fatalf("customer route: got %d, want 204", rec.Code) }
}
