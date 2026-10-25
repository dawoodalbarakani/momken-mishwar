package httpapi

import (
 "context"
  "net/http"
 "net/http/httptest"
 "strings"
 "testing"

 "github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"

 "github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

type testRevoker struct { token, reason string; err error; calls int }
func (f *testRevoker) Revoke(_ context.Context, token, reason string) error { f.calls++; f.token=token; f.reason=reason; return f.err }

func TestLogoutHandlerReturnsNoContent(t *testing.T) {
 revoker := &testRevoker{}
 mux := http.NewServeMux()
 (AuthHandlers{RefreshTokens:revoker}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", strings.NewReader(`{"refresh_token":"secret"}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec,req)
 if rec.Code != http.StatusNoContent { t.Fatalf("status = %d, want 204",rec.Code) }
 if revoker.calls != 1 || revoker.token != "secret" || revoker.reason != "LOGOUT" { t.Fatalf("unexpected revoke call: %#v",revoker) }
}

func TestLogoutHandlerIsIdempotentForUnknownToken(t *testing.T) {
 revoker := &testRevoker{err: domain.ErrRefreshTokenInvalid}
 mux := http.NewServeMux()
 (AuthHandlers{RefreshTokens:revoker}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", strings.NewReader(`{"refresh_token":"unknown"}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec,req)
 if rec.Code != http.StatusNoContent { t.Fatalf("status = %d, want 204",rec.Code) }
}


func TestLogoutHandlerRejectsMalformedBodyWithoutRevoking(t *testing.T) {
 revoker := &testRevoker{}
 mux := http.NewServeMux()
 (AuthHandlers{RefreshTokens:revoker}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", strings.NewReader(`{"refresh_token":123}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec,req)
 if rec.Code != http.StatusBadRequest { t.Fatalf("status = %d, want 400",rec.Code) }
 if revoker.calls != 0 { t.Fatal("invalid body must not revoke a token") }
}


type testRefresher struct { token string; err error; calls int }
func (f *testRefresher) Refresh(_ context.Context, token string, _ *string) (service.RefreshSessionResult, error) {
 f.calls++
 f.token = token
 return service.RefreshSessionResult{}, f.err
}

func TestRefreshHandlerRejectsInvalidCredential(t *testing.T) {
 refresher := &testRefresher{err: domain.ErrRefreshTokenInvalid}
 mux := http.NewServeMux()
 (AuthHandlers{RefreshSessions:refresher}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh", strings.NewReader(`{"refresh_token":"old-token"}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec, req)
 if rec.Code != http.StatusUnauthorized { t.Fatalf("status = %d, want 401; body=%s", rec.Code, rec.Body.String()) }
 if refresher.calls != 1 || refresher.token != "old-token" { t.Fatalf("unexpected refresh invocation: %#v", refresher) }
}

func TestRefreshHandlerRejectsMalformedCredential(t *testing.T) {
 refresher := &testRefresher{}
 mux := http.NewServeMux()
 (AuthHandlers{RefreshSessions:refresher}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/refresh", strings.NewReader(`{"refresh_token":123}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec, req)
 if rec.Code != http.StatusBadRequest { t.Fatalf("status = %d, want 400", rec.Code) }
 if refresher.calls != 0 { t.Fatal("malformed request must not rotate credentials") }
}
