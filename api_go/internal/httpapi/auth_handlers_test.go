package httpapi

import (
 "context"
 "errors"
 "net/http"
 "net/http/httptest"
 "strings"
 "testing"
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
 revoker := &testRevoker{err: errors.New("unknown token")}
 mux := http.NewServeMux()
 (AuthHandlers{RefreshTokens:revoker}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", strings.NewReader(`{"refresh_token":"unknown"}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec,req)
 if rec.Code != http.StatusNoContent { t.Fatalf("status = %d, want 204",rec.Code) }
}
