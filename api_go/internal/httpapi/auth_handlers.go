package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"strings"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
)

type OTPRequester interface {
	Request(ctx context.Context, phoneE164, clientIP string, purpose domain.OTPPurpose) error
}

type SessionLogin interface {
	Login(ctx context.Context, phoneE164, code string, deviceID *string) (service.LoginSession, error)
}

type SessionRefresher interface {
	Refresh(ctx context.Context, rawToken string, deviceID *string) (service.RefreshSessionResult, error)
}

type SessionRevoker interface {
	Revoke(ctx context.Context, rawToken, reason string) error
}

type AuthHandlers struct {
	OTP             OTPRequester
	Sessions        SessionLogin
	RefreshSessions SessionRefresher
	RefreshTokens   SessionRevoker
}

type otpRequest struct {
	PhoneE164 string `json:"phone_e164"`
}

type loginRequest struct {
	PhoneE164 string  `json:"phone_e164"`
	Code      string  `json:"code"`
	DeviceID  *string `json:"device_id,omitempty"`
}

type refreshRequest struct {
	RefreshToken string  `json:"refresh_token"`
	DeviceID     *string `json:"device_id,omitempty"`
}

func (h AuthHandlers) Register(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/auth/otp/request", h.requestOTP)
	mux.HandleFunc("POST /api/v1/auth/otp/verify", h.login)
	mux.HandleFunc("POST /api/v1/auth/refresh", h.refresh)
	mux.HandleFunc("POST /api/v1/auth/logout", h.logout)
}

func (h AuthHandlers) requestOTP(w http.ResponseWriter, r *http.Request) {
	if h.OTP == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "authentication_unavailable"})
		return
	}
	var input otpRequest
	if err := decodeJSON(w, r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	if err := h.OTP.Request(r.Context(), strings.TrimSpace(input.PhoneE164), clientIP(r), domain.OTPPurposeLogin); err != nil {
		if errors.Is(err, service.ErrOTPRequestLimited) {
			writeJSON(w, http.StatusTooManyRequests, map[string]string{"error": "try_again_later"})
			return
		}
		if errors.Is(err, service.ErrInvalidPhone) {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
			return
		}
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "otp_delivery_unavailable"})
		return
	}
	// The response does not reveal the OTP, and is identical for existing and
	// non-existing accounts to reduce account enumeration.
	writeJSON(w, http.StatusAccepted, map[string]string{"status": "accepted"})
}

func (h AuthHandlers) login(w http.ResponseWriter, r *http.Request) {
	if h.Sessions == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "authentication_unavailable"})
		return
	}
	var input loginRequest
	if err := decodeJSON(w, r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	input.PhoneE164 = strings.TrimSpace(input.PhoneE164)
	input.Code = strings.TrimSpace(input.Code)
	if input.DeviceID != nil {
		device := strings.TrimSpace(*input.DeviceID)
		if device == "" || len(device) > 128 {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
			return
		}
		input.DeviceID = &device
	}
	session, err := h.Sessions.Login(r.Context(), input.PhoneE164, input.Code, input.DeviceID)
	if err != nil {
		switch {
		case errors.Is(err, domain.ErrUserInactive):
			writeJSON(w, http.StatusForbidden, map[string]string{"error": "account_unavailable"})
		case errors.Is(err, domain.ErrInvalidOTPChallenge):
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid_otp"})
		case errors.Is(err, service.ErrInvalidPhone):
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		default:
			// Keep OTP mismatch, missing users, and internal failures indistinguishable
			// to public callers. Internal errors should be logged by observability middleware.
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "authentication_failed"})
		}
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"access_token":       session.AccessToken,
		"token_type":         "Bearer",
		"expires_at":         session.AccessTokenExpiresAt,
		"refresh_token":      session.RefreshToken,
		"refresh_expires_at": session.RefreshTokenExpiresAt,
		"user": map[string]any{
			"id":           session.User.ID,
			"phone_e164":   session.User.PhoneE164,
			"display_name": session.User.DisplayName,
			"locale":       session.User.Locale,
			"roles":        session.User.Roles,
		},
	})
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) error {
	r.Body = http.MaxBytesReader(w, r.Body, 16<<10)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		return errors.New("request must contain exactly one JSON value")
	}
	return nil
}

func clientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err == nil {
		return host
	}
	return r.RemoteAddr
}

func (h AuthHandlers) refresh(w http.ResponseWriter, r *http.Request) {
	if h.RefreshSessions == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "authentication_unavailable"})
		return
	}
	var input refreshRequest
	if err := decodeJSON(w, r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	input.RefreshToken = strings.TrimSpace(input.RefreshToken)
	if input.RefreshToken == "" || len(input.RefreshToken) > 512 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	if input.DeviceID != nil {
		device := strings.TrimSpace(*input.DeviceID)
		if device == "" || len(device) > 128 {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
			return
		}
		input.DeviceID = &device
	}
	session, err := h.RefreshSessions.Refresh(r.Context(), input.RefreshToken, input.DeviceID)
	if err != nil {
		switch {
		case errors.Is(err, domain.ErrUserInactive):
			writeJSON(w, http.StatusForbidden, map[string]string{"error": "account_unavailable"})
		case errors.Is(err, domain.ErrRefreshTokenInvalid), errors.Is(err, domain.ErrRefreshTokenExpired), errors.Is(err, domain.ErrRefreshTokenReuse):
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid_refresh_token"})
		default:
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "authentication_failed"})
		}
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"access_token": session.AccessToken, "token_type": "Bearer", "expires_at": session.AccessTokenExpiresAt, "refresh_token": session.RefreshToken, "refresh_expires_at": session.RefreshTokenExpiresAt, "user": map[string]any{"id": session.User.ID, "phone_e164": session.User.PhoneE164, "display_name": session.User.DisplayName, "locale": session.User.Locale, "roles": session.User.Roles}})
}

type logoutRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (h AuthHandlers) logout(w http.ResponseWriter, r *http.Request) {
	if h.RefreshTokens == nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "authentication_unavailable"})
		return
	}
	var input logoutRequest
	if err := decodeJSON(w, r, &input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	input.RefreshToken = strings.TrimSpace(input.RefreshToken)
	if input.RefreshToken == "" || len(input.RefreshToken) > 512 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_request"})
		return
	}
	if err := h.RefreshTokens.Revoke(r.Context(), input.RefreshToken, "LOGOUT"); err != nil {
		if errors.Is(err, domain.ErrRefreshTokenInvalid) {
			// Idempotent logout avoids revealing whether a credential ever existed.
			w.WriteHeader(http.StatusNoContent)
			return
		}
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "logout_failed"})
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
