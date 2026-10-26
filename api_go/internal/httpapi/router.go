package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	adminSvc "github.com/barakanid96/momken-mishwar/api_go/internal/modules/admin/service"
	dispatchSvc "github.com/barakanid96/momken-mishwar/api_go/internal/modules/dispatch/service"
	driversSvc "github.com/barakanid96/momken-mishwar/api_go/internal/modules/drivers/service"
	identitydomain "github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	identitySvc "github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/service"
	locationsSvc "github.com/barakanid96/momken-mishwar/api_go/internal/modules/locations/service"
	paymentsSvc "github.com/barakanid96/momken-mishwar/api_go/internal/modules/payments/service"
	ridesSvc "github.com/barakanid96/momken-mishwar/api_go/internal/modules/rides/service"
	tripsSvc "github.com/barakanid96/momken-mishwar/api_go/internal/modules/trips/service"
)

type RouterConfig struct {
	Auth        *AuthHandlers
	Tokens      *identitySvc.AccessTokenService
	Users       UserFinder
	RideService *ridesSvc.RideService
	DispatchSvc *dispatchSvc.DispatchService
	TripService *tripsSvc.TripService
	DriverSvc   *driversSvc.DriverService
	PaymentSvc  *paymentsSvc.PaymentService
	LocationSvc *locationsSvc.LocationService
	AdminSvc    *adminSvc.AdminService
}

// UserFinder retrieves user records for authenticated requests.
type UserFinder interface {
	FindByID(ctx context.Context, id string) (identitydomain.User, error)
}

type API struct {
	logger *slog.Logger
	db     *pgxpool.Pool
	users  UserFinder

	rideSvc     *ridesSvc.RideService
	dispatchSvc *dispatchSvc.DispatchService
	tripSvc     *tripsSvc.TripService
	driverSvc   *driversSvc.DriverService
	paymentSvc  *paymentsSvc.PaymentService
	locationSvc *locationsSvc.LocationService
	adminSvc    *adminSvc.AdminService
}

func New(logger *slog.Logger, db *pgxpool.Pool) http.Handler {
	return NewWithConfig(logger, db, RouterConfig{})
}

func NewWithAuth(logger *slog.Logger, db *pgxpool.Pool, auth *AuthHandlers) http.Handler {
	return NewWithConfig(logger, db, RouterConfig{Auth: auth})
}

func NewWithConfig(logger *slog.Logger, db *pgxpool.Pool, cfg RouterConfig) http.Handler {
	api := &API{
		logger:      logger,
		db:          db,
		users:       cfg.Users,
		rideSvc:     cfg.RideService,
		dispatchSvc: cfg.DispatchSvc,
		tripSvc:     cfg.TripService,
		driverSvc:   cfg.DriverSvc,
		paymentSvc:  cfg.PaymentSvc,
		locationSvc: cfg.LocationSvc,
		adminSvc:    cfg.AdminSvc,
	}
	mux := http.NewServeMux()
	if cfg.Auth != nil {
		cfg.Auth.Register(mux)
	}
	if cfg.Tokens != nil {
		mux.Handle("GET /api/v1/auth/me", RequireAccessToken(cfg.Tokens, http.HandlerFunc(api.me)))
	}
	if cfg.RideService != nil {
		mux.Handle("POST /api/v1/rides", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleCustomer)(http.HandlerFunc(api.createRide))))
		mux.Handle("GET /api/v1/rides/active", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleCustomer)(http.HandlerFunc(api.activeRide))))
		mux.Handle("GET /api/v1/rides/{id}", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleCustomer, identitydomain.RoleDriver, identitydomain.RoleSupportAgent, identitydomain.RoleOperationsManager, identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin)(http.HandlerFunc(api.getRide))))
		mux.Handle("POST /api/v1/rides/{id}/cancel", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleCustomer)(http.HandlerFunc(api.cancelRide))))
	}
	if cfg.DispatchSvc != nil {
		mux.Handle("POST /api/v1/dispatch/rides/{rideId}/search", RequireAccessToken(cfg.Tokens, http.HandlerFunc(api.dispatchSearch)))
		mux.Handle("POST /api/v1/dispatch/offers/{offerId}/accept", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.dispatchAcceptOffer))))
		mux.Handle("POST /api/v1/dispatch/sweep", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin)(http.HandlerFunc(api.dispatchSweep))))
	}
	if cfg.TripService != nil {
		mux.Handle("POST /api/v1/rides/{id}/en-route", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.tripEnRoute))))
		mux.Handle("POST /api/v1/rides/{id}/arrived", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.tripArrived))))
		mux.Handle("POST /api/v1/rides/{id}/start", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.tripStart))))
		mux.Handle("POST /api/v1/rides/{id}/complete", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.tripComplete))))
		mux.Handle("GET /api/v1/rides/{id}/start-code", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleCustomer)(http.HandlerFunc(api.tripStartCode))))
	}
	if cfg.DriverSvc != nil {
		mux.Handle("GET /api/v1/drivers/me/profile", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.driverProfile))))
		mux.Handle("POST /api/v1/drivers/me/availability", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.driverAvailability))))
		mux.Handle("GET /api/v1/drivers", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin, identitydomain.RoleOperationsManager, identitydomain.RoleSupportAgent)(http.HandlerFunc(api.driverList))))
		mux.Handle("POST /api/v1/vehicles", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.createVehicle))))
		mux.Handle("GET /api/v1/vehicles/me", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.listVehicles))))
	}
	if cfg.PaymentSvc != nil {
		mux.Handle("POST /api/v1/payments/rides/{rideId}", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleCustomer, identitydomain.RoleDriver)(http.HandlerFunc(api.createPayment))))
		mux.Handle("GET /api/v1/payments", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleFinanceManager, identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin)(http.HandlerFunc(api.listPayments))))
		mux.Handle("POST /api/v1/driver/payout-requests", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.requestPayout))))
		mux.Handle("GET /api/v1/driver/earnings", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.driverEarnings))))
		mux.Handle("GET /api/v1/driver/ledger", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.driverLedger))))
		mux.Handle("POST /api/v1/admin/payouts/{id}/approve", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleFinanceManager, identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin)(http.HandlerFunc(api.approvePayout))))
		mux.Handle("GET /api/v1/admin/driver-balances", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleFinanceManager, identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin)(http.HandlerFunc(api.driverBalances))))
	}
	if cfg.LocationSvc != nil {
		mux.Handle("POST /api/v1/driver/location", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.updateLocation))))
		mux.Handle("GET /api/v1/driver/location/latest", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleDriver)(http.HandlerFunc(api.latestLocation))))
	}
	if cfg.AdminSvc != nil {
		mux.Handle("GET /api/v1/admin/drivers", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin, identitydomain.RoleOperationsManager, identitydomain.RoleSupportAgent)(http.HandlerFunc(api.adminListDrivers))))
		mux.Handle("GET /api/v1/admin/rides", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin, identitydomain.RoleOperationsManager, identitydomain.RoleSupportAgent)(http.HandlerFunc(api.adminListRides))))
		mux.Handle("POST /api/v1/admin/rides/{id}/cancel", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin, identitydomain.RoleOperationsManager, identitydomain.RoleSupportAgent)(http.HandlerFunc(api.adminCancelRide))))
		mux.Handle("GET /api/v1/admin/pricing-rules", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin, identitydomain.RoleOperationsManager)(http.HandlerFunc(api.adminListPricingRules))))
		mux.Handle("GET /api/v1/admin/payouts", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleFinanceManager, identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin)(http.HandlerFunc(api.adminListPayouts))))
		mux.Handle("GET /api/v1/admin/dashboard/stats", RequireAccessToken(cfg.Tokens, RequireAnyRole(identitydomain.RoleAdmin, identitydomain.RoleSuperAdmin, identitydomain.RoleOperationsManager)(http.HandlerFunc(api.adminStats))))
	}
	mux.HandleFunc("GET /health/live", api.live)
	mux.HandleFunc("GET /health/ready", api.ready)
	mux.HandleFunc("GET /api/v1", api.index)
	RegisterDocs(mux, logger)
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

// Placeholder handler implementations (to be fully wired)

func (a *API) createRide(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) activeRide(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) getRide(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) cancelRide(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) dispatchSearch(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) dispatchAcceptOffer(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) dispatchSweep(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) tripEnRoute(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) tripArrived(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) tripStart(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) tripComplete(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) tripStartCode(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) driverProfile(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) driverAvailability(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) driverList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) createVehicle(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) listVehicles(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) createPayment(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) listPayments(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) requestPayout(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) driverEarnings(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) driverLedger(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) approvePayout(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) driverBalances(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) updateLocation(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) latestLocation(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) adminListDrivers(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) adminListRides(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) adminCancelRide(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) adminListPricingRules(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) adminListPayouts(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}
func (a *API) adminStats(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotImplemented, map[string]string{"error": "not_implemented"})
}

var _ = io.EOF
var _ = net.SplitHostPort
