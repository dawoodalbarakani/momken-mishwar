package httpapi

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestLivenessEndpoint(t *testing.T) {
	handler := New(slog.New(slog.NewTextHandler(io.Discard, nil)), nil)
	req := httptest.NewRequest(http.MethodGet, "/health/live", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK { t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK) }
	if !strings.Contains(rec.Body.String(), "`status`:`ok`") && !strings.Contains(rec.Body.String(), "`status`") {
		// JSON response is validated below without depending on key ordering.
		if !strings.Contains(rec.Body.String(), "\"status\":\"ok\"") { t.Fatalf("unexpected body: %s", rec.Body.String()) }
	}
}
