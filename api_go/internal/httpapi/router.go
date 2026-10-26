package httpapi

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
)

// UserFinder retrieves user records for authenticated requests.
type UserFinder interface {
	FindByID(ctx context.Context, id string) (domain.User, error)
}

// RouterConfig contains services and adapters wired into the HTTP router.
type RouterConfig struct {
	Auth   *AuthHandlers
	Tokens *service.AccessTokenService
	Users  UserFinder
}

// API provides HTTP request handlers for health checks and service metadata.
type API struct {
	logger *slog.Logger
	db     *pgxpool.Pool
	users  UserFinder
}

// New creates an HTTP handler with standard middleware and unauthenticated endpoints.
func New(logger *slog.Logger, db *pgxpool.Pool) http.Handler {
	return NewWithConfig(logger, db, RouterConfig{})
}

// NewWithAuth creates an HTTP handler with registered authentication endpoints.
func NewWithAuth(logger *slog.Logger, db *pgxpool.Pool, auth *AuthHandlers) http.Handler {
	return NewWithConfig(logger, db, RouterConfig{Auth: auth})
}

// NewWithConfig creates an HTTP handler with full service dependencies and token validation.
func NewWithConfig(logger *slog.Logger, db *pgxpool.Pool, cfg RouterConfig) http.Handler {
	api := &API{logger: logger, db: db, users: cfg.Users}
	mux := http.NewServeMux()
	if cfg.Auth != nil {
		cfg.Auth.Register(mux)
	}
	if cfg.Tokens != nil {
		mux.Handle("GET /api/v1/auth/me", RequireAccessToken(cfg.Tokens, http.HandlerFunc(api.me)))
	}
	mux.HandleFunc("GET /health/live", api.live)
	mux.HandleFunc("GET /health/ready", api.ready)
	mux.HandleFunc("GET /api/v1", api.index)
	return requestID(recoverPanic(logger, mux))
}

func (a *API) live(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "service": "api_go"})
}

func (a *API) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if a.db == nil || a.db.Ping(ctx) != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{"status": "not_ready", "dependency": "postgres"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ready", "service": "api_go", "dependencies": map[string]string{"postgres": "ok"}})
}

func (a *API) index(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"service": "Mishwar Go API",
		"version": "v1",
		"status":  "scaffold",
		"message": "Business endpoints are being ported incrementally; existing API remains the contract source of truth.",
	})
}

func (a *API) me(w http.ResponseWriter, r *http.Request) {
	claims, ok := AccessTokenClaimsFromContext(r.Context())
	if !ok {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
		return
	}
	if a.users != nil {
		user, err := a.users.FindByID(r.Context(), claims.Subject)
		if err == nil {
			writeJSON(w, http.StatusOK, map[string]any{
				"id":           user.ID,
				"phone_e164":   user.PhoneE164,
				"display_name": user.DisplayName,
				"locale":       user.Locale,
				"status":       user.Status,
				"roles":        user.Roles,
			})
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"id":    claims.Subject,
		"roles": claims.Roles,
	})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func requestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}

func recoverPanic(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				logger.Error("panic recovered", "panic", recovered, "path", r.URL.Path)
				writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal_server_error"})
			}
		}()
		next.ServeHTTP(w, r)
	})
}
