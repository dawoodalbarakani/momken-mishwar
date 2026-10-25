package httpapi

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type API struct {
	logger *slog.Logger
	db *pgxpool.Pool
}

func New(logger *slog.Logger, db *pgxpool.Pool) http.Handler {
	api := &API{logger: logger, db: db}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health/live", api.live)
	mux.HandleFunc("GET /health/ready", api.ready)
	mux.HandleFunc("GET /api/v1", api.index)
	return requestID(recoverPanic(logger, mux))
}

func (a *API) live(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"status":"ok", "service":"api_go"})
}

func (a *API) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := timeLimit(r, 2*time.Second)
	defer cancel()
	if err := a.db.Ping(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{"status":"not_ready", "dependency":"postgres"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status":"ready", "service":"api_go", "dependencies":map[string]string{"postgres":"ok"}})
}

func (a *API) index(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"service":"Mishwar Go API",
		"version":"v1",
		"status":"scaffold",
		"message":"Business endpoints are being ported incrementally; existing API remains the contract source of truth.",
	})
}

func timeLimit(r *http.Request, d time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(r.Context(), d)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func requestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Do not trust a client-supplied request ID as a unique server identifier.
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}

func recoverPanic(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				logger.Error("panic recovered", "panic", recovered, "path", r.URL.Path)
				writeJSON(w, http.StatusInternalServerError, map[string]string{"error":"internal_server_error"})
			}
		}()
		next.ServeHTTP(w, r)
	})
}
