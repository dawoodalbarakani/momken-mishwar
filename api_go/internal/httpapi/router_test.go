package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
)

type mockUserFinder struct {
	user domain.User
	err  error
}

func (m *mockUserFinder) FindByID(ctx context.Context, id string) (domain.User, error) {
	if m.err != nil {
		return domain.User{}, m.err
	}
	return m.user, nil
}

func TestLivenessEndpoint(t *testing.T) {
	handler := New(slog.New(slog.NewTextHandler(io.Discard, nil)), nil)
	req := httptest.NewRequest(http.MethodGet, "/health/live", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body["status"] != "ok" || body["service"] != "api_go" {
		t.Fatalf("unexpected response: %#v", body)
	}
}

func TestIndexEndpoint(t *testing.T) {
	handler := New(slog.New(slog.NewTextHandler(io.Discard, nil)), nil)
	req := httptest.NewRequest(http.MethodGet, "/api/v1", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body["service"] != "Mishwar Go API" || body["version"] != "v1" {
		t.Fatalf("unexpected response: %#v", body)
	}
}

func TestMeEndpoint(t *testing.T) {
	signingKey := []byte("01234567890123456789012345678901")
	tokenService, err := service.NewAccessTokenService(service.AccessTokenConfig{
		SigningKey: signingKey,
		Issuer:     "mishwar-api",
		Audience:   "mishwar-clients",
		TTL:        15 * time.Minute,
	})
	if err != nil {
		t.Fatalf("unexpected error creating token service: %v", err)
	}

	phone := "+967770000001"
	name := "Test Rider"
	now := time.Now().UTC()
	testUser := domain.User{
		ID:          "11111111-1111-1111-1111-111111111111",
		PhoneE164:   &phone,
		DisplayName: &name,
		Locale:      "ar",
		Status:      domain.UserActive,
		Roles:       []domain.Role{domain.RoleCustomer},
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	finder := &mockUserFinder{user: testUser}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	handler := NewWithConfig(logger, nil, RouterConfig{
		Tokens: tokenService,
		Users:  finder,
	})

	t.Run("unauthorized without token", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
		}
	})

	t.Run("authorized with valid token returns user profile", func(t *testing.T) {
		token, _, err := tokenService.Issue(testUser)
		if err != nil {
			t.Fatalf("unexpected issue error: %v", err)
		}

		req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/me", nil)
		req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", token))
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
		}
		var resp map[string]any
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatalf("decode response: %v", err)
		}
		if resp["id"] != testUser.ID || resp["display_name"] != *testUser.DisplayName {
			t.Fatalf("unexpected user response: %#v", resp)
		}
	})
}
