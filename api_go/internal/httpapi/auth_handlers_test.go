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


type testOTPRequester struct {
 phone, ip string
 purpose domain.OTPPurpose
 err error
 calls int
}
func (f *testOTPRequester) Request(_ context.Context, phone, ip string, purpose domain.OTPPurpose) error {
 f.calls++
 f.phone, f.ip, f.purpose = phone, ip, purpose
 return f.err
}

func TestOTPRequestAcceptedAndDoesNotExposeCode(t *testing.T) {
 requester := &testOTPRequester{}
 mux := http.NewServeMux()
 (AuthHandlers{OTP: requester}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/otp/request", strings.NewReader(`{"phone_e164":" +967771234567 "}`))
 req.RemoteAddr = "192.0.2.1:1234"
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec, req)
 if rec.Code != http.StatusAccepted { t.Fatalf("status = %d, want 202; body=%s", rec.Code, rec.Body.String()) }
 if requester.calls != 1 || requester.phone != "+967771234567" || requester.ip != "192.0.2.1" || requester.purpose != domain.OTPPurposeLogin {
  t.Fatalf("unexpected OTP request: %#v", requester)
 }
 if strings.Contains(rec.Body.String(), "code") || strings.Contains(rec.Body.String(), "otp") {
  t.Fatalf("response must not expose OTP details: %s", rec.Body.String())
 }
}

func TestOTPRequestRateLimitReturnsTooManyRequests(t *testing.T) {
 requester := &testOTPRequester{err: service.ErrOTPRequestLimited}
 mux := http.NewServeMux()
 (AuthHandlers{OTP: requester}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/otp/request", strings.NewReader(`{"phone_e164":"+967771234567"}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec, req)
 if rec.Code != http.StatusTooManyRequests { t.Fatalf("status = %d, want 429", rec.Code) }
}

type testSessionLogin struct {
 phone, code string
 deviceID *string
 result service.LoginSession
 err error
 calls int
}
func (f *testSessionLogin) Login(_ context.Context, phone, code string, deviceID *string) (service.LoginSession, error) {
 f.calls++
 f.phone, f.code, f.deviceID = phone, code, deviceID
 return f.result, f.err
}

func TestLoginRejectsInvalidOTP(t *testing.T) {
 login := &testSessionLogin{err: domain.ErrInvalidOTPChallenge}
 mux := http.NewServeMux()
 (AuthHandlers{Sessions: login}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/otp/verify", strings.NewReader(`{"phone_e164":" +967771234567 ","code":" 123456 "}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec, req)
 if rec.Code != http.StatusUnauthorized { t.Fatalf("status = %d, want 401; body=%s", rec.Code, rec.Body.String()) }
 if login.calls != 1 || login.phone != "+967771234567" || login.code != "123456" {
  t.Fatalf("unexpected login invocation: %#v", login)
 }
}

func TestLoginRejectsMalformedBodyWithoutCallingService(t *testing.T) {
 login := &testSessionLogin{}
 mux := http.NewServeMux()
 (AuthHandlers{Sessions: login}).Register(mux)
 req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/otp/verify", strings.NewReader(`{"phone_e164":"+967771234567","code":123456}`))
 rec := httptest.NewRecorder()
 mux.ServeHTTP(rec, req)
 if rec.Code != http.StatusBadRequest { t.Fatalf("status = %d, want 400", rec.Code) }
 if login.calls != 0 { t.Fatal("malformed request must not invoke login service") }
}
