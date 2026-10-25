package httpapi

import (
	"net/http"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

// RequireAnyRole must be wrapped inside RequireAccessToken. It returns 401 if
// verified claims are absent and 403 if the caller has none of the allowed roles.
func RequireAnyRole(allowed ...domain.Role) func(http.Handler) http.Handler {
	roleSet := make(map[domain.Role]struct{}, len(allowed))
	for _, role := range allowed {
		if role != "" {
			roleSet[role] = struct{}{}
		}
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims, ok := AccessTokenClaimsFromContext(r.Context())
			if !ok {
				writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
				return
			}
			for _, role := range claims.Roles {
				if _, ok := roleSet[role]; ok {
					next.ServeHTTP(w, r)
					return
				}
			}
			writeJSON(w, http.StatusForbidden, map[string]string{"error": "forbidden"})
		})
	}
}
