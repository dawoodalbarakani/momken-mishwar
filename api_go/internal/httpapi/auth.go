package httpapi

import (
	"context"
	"net/http"
	"strings"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
)

type accessTokenContextKey struct{}

// AccessTokenClaimsFromContext retrieves verified claims added by RequireAccessToken.
func AccessTokenClaimsFromContext(ctx context.Context) (service.AccessTokenClaims, bool) {
	claims, ok := ctx.Value(accessTokenContextKey{}).(service.AccessTokenClaims)
	return claims, ok
}

// RequireAccessToken validates a bearer JWT before passing the request downstream.
// It is intentionally not attached to public health or OTP routes automatically.
func RequireAccessToken(tokens *service.AccessTokenService, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if tokens == nil {
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "authentication_unavailable"})
			return
		}
		header := r.Header.Get("Authorization")
		parts := strings.Fields(header)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			w.Header().Set("WWW-Authenticate", "Bearer")
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		claims, err := tokens.Verify(parts[1])
		if err != nil {
			w.Header().Set("WWW-Authenticate", `Bearer error="invalid_token"`)
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		ctx := context.WithValue(r.Context(), accessTokenContextKey{}, claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
