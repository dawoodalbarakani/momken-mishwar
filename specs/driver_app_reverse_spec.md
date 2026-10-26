# Reverse-Engineered Specification: Mishwar Yemen Driver App (`apps/driver_app`)

> **How this document was produced.** Static reverse-engineering of the Flutter driver client only.
> Evidence = every file under `apps/driver_app/lib` (47 Dart files, ~4.4k LOC), all 7 files under
> `apps/driver_app/test`, and the existing contract documents `docs/api-specification.md`,
> `docs/user-flows.md`, `docs/codebase/CONCERNS.md`, `docs/adr/0005-money-representation.md`.
> Requirements marked **OBS** are behaviours observed in code. Anything inferred (not proven by code
> or test) is explicitly labelled *Inference*. No runtime verification was performed for this document;
> the widget/unit suite status is tracked separately (see §10).

---

## 1. Overview

`driver_app` is the driver-side client of the Mishwar Yemen ride-hailing platform: Arabic-first, full
RTL, mobile/tablet/desktop responsive, styled with an Uber-derived design system. It implements the
driver half of the ride lifecycle — sign in by phone OTP, pass a document/verification gate, go
available, receive and answer dispatch offers, verify assignment, start a trip with the rider's start
code, complete or cancel it, and review earnings and request a payout.

Two entry points exist and share the entire widget tree:

| Entry point | Back end | Purpose |
|---|---|---|
| `lib/main.dart` | Live HTTP/WS via `DioClient` → `MISHWAR_API_BASE_URL` (default `http://10.0.2.2:4000`) | Real app |
| `lib/main_demo.dart` | 8 in-memory repository overrides (`demoOverrides`) | Demo/tests, no backend |

Demo credentials (const in `data/mock/demo_data.dart`): phone `+967770000001`, OTP `123456`,
ride `demo-ride-1`, start code `4821`.

---

## 2. Architecture Summary

### 2.1 Technology stack

| Concern | Choice | Evidence |
|---|---|---|
| Language / SDK | Dart, `sdk: >=3.0.0 <4.0.0`, `flutter: >=3.16.0` | `pubspec.yaml:5-7` |
| State | `flutter_riverpod ^2.5.1` (`Notifier`, `NotifierProvider.family`) | `pubspec.yaml:15` |
| Routing | `go_router ^14.0.0` (`redirect`, `refreshListenable`, `ShellRoute`) | `pubspec.yaml:16`, `app_router.dart:23-94` |
| HTTP | `dio ^5.4.0` + custom `DioClient` + interceptors | `pubspec.yaml:17`, `data/services/dio_client.dart` |
| Tokens | `flutter_secure_storage ^9.0.0` | `data/services/secure_storage_service.dart` |
| Realtime | `web_socket_channel ^2.4.0` (**declared, never consumed** — see D4) | `pubspec.yaml:19`, `data/services/offers_service.dart:26` |
| Connectivity | `connectivity_plus ^6.0.0` | `data/services/connectivity_service.dart` |
| Maps | `google_maps_flutter ^2.5.0` (**stub service, no UI consumer** — see D11) | `pubspec.yaml:21`, `data/services/map_service.dart:47-66` |
| Localization | `flutter_localizations` + `intl` (only `ar_YE` strings are implemented) | `main.dart:24-38`, `pubspec.yaml:12-14` |
| Testing | `flutter_test`, `mockito ^5.4.0`, hand-written mocks, `integration_test` declared but unused | `pubspec.yaml:24-31` |

The app has **no code generation** (no `.g.dart`/`.freezed.dart`); all (de)serialization is hand-written
in repositories and `data/models/auth_api_models.dart` (which is currently unused by the repositories —
they parse maps inline).

### 2.2 Layering

```
ui/features/<feature>/{views,view_models}     widgets + Riverpod Notifiers (state, guards, copy)
        ↓ ref.read
data/repositories/*                          domain<->wire mapping, exception→bool/null folding
        ↓
data/services/*                              Dio endpoints, secure storage, connectivity, map, WS
        ↓
domain/models/*                              immutable models (Offer, Ride, EarningsState, ...)
ui/core/{app_theme,responsive,uber_components}  design tokens, breakpoints, shared primitives
```

Rules observed without exception:
- Only view-models touch repositories; only repositories touch services; views never call `Dio`.
- No view writes provider state during build; deferred writes use `Future(...)`/post-frame callbacks
  (`earnings_view_model.dart:10`, `app_router.dart:206`, `home_screen.dart:24`, `offers_screen.dart:33`).
- Every repository method swallows exceptions into `false`/`null`; view-models translate those into
  Arabic strings (see §5.8).

### 2.3 Module structure

```
lib/
├── main.dart / main_demo.dart        entry points (ProviderScope, demoOverrides)
├── app_router.dart                   GoRouter + guards + nav shell + SplashScreen + ProfileScreen
├── core/{app_constants,demo_mode}.dart
├── data/
│   ├── models/auth_api_models.dart   ApiModel DTOs (currently unused)
│   ├── repositories/                 auth, ride, offers, earnings, documents, map
│   ├── services/                     dio_client, auth, ride, offers, earnings, documents,
│   │                                 secure_storage, connectivity, map
│   └── mock/{demo_data,demo_repositories}.dart
├── domain/models/                    auth_user, available_ride, offer, ride, earnings, document
└── ui/
    ├── core/                         app_theme, responsive, uber_components
    └── features/
        ├── auth/          login, otp, register, documents (+ 2 notifiers)
        ├── home/          availability + queue
        ├── offers/        request inbox + accept/reject
        ├── ride_tracking/ verify → start → complete/cancel
        └── earnings/      summary + payout request
```

### 2.4 Request/data flow

```
Tap → View (ConsumerWidget)
      → Notifier.method()  ── sets isLoading, clears error
        → Repository.method()  ── try { Service → DioClient → Dio (+Auth, +Idempotency, +Log) }
        │                        catch (_) → false / null
      → state = copyWith(...)  ── tokens, domain objects, Arabic error
      → View rebuilds (UberErrorText / UberStatusPill / SnackBar)

Session:  SecureStorage(read) → AuthInterceptor adds "Authorization: Bearer <token>" per request
Offers:   OffersScreen post-frame → fetchOffers() → per-offer one-shot expiry Timer → accepted/rejected
Trip:     RideTrackingNotifier(rideId) build → _restore() → verify → start(code) → complete/cancel
```

### 2.5 State ownership

| Provider | State | Lifetime | Notes |
|---|---|---|---|
| `authViewModelProvider` | `AuthState` (token, user, isInitializing, error) | app | drives all routing via `ref.listen` |
| `homeViewModelProvider` | `HomeState` (availability, availableRides, connectionStatus, lastLocationUpdate) | app | subscribes to connectivity in `build()` |
| `offersViewModelProvider` | `OffersState` (offers, activeRideId, selectedOffer, accepting) | app | owns per-offer `Timer`s |
| `rideTrackingViewModelProvider(rideId)` | `RideTrackingState` | per ride | family key = ride id |
| `earningsViewModelProvider` | `EarningsState` | app | self-fetching on build |
| `documentsViewModelProvider` | `DocumentsState` | app | one entry per `DocumentType` |

`activeRideId` is **in-memory only** — it is not persisted and not restored from the server (see D2).

### 2.6 Platform layer (Android)

| Observation | Evidence |
|---|---|
| Targets `android/` and `web/` only — **no `ios/` directory** | directory listing |
| `INTERNET` is declared **only in the debug manifest**; the main manifest declares **zero** `uses-permission` entries | `android/app/src/debug/AndroidManifest.xml:6`, `android/app/src/main/AndroidManifest.xml` |
| No location permission (`ACCESS_FINE_LOCATION` / `ACCESS_BACKGROUND_LOCATION`), no `FOREGROUND_SERVICE*` permission, no service declaration | same manifest (no matches) |
| No background-execution package (`flutter_background_service`, `workmanager`, `geolocator`) — dispatch can only run while a UI is attached | `pubspec.yaml:7-19` |
| Google Maps key inlined in the manifest as `com.google.android.geo.API_KEY`, while `README-SETUP.md:24` instructs that it must not be committed | `android/app/src/main/AndroidManifest.xml:29`, `README-SETUP.md:24` |

Consequences: (a) a **release** build has no network capability at all, so every behaviour in §3 is
unreachable in release (D20); (b) `POST /driver/location` and `HomeState.lastLocationUpdate` can never
receive a real fix (D21); (c) offers, trip timers and location reporting stop the moment the app is
backgrounded (D22).

---

## 3. Observed Functional Requirements (EARS)

### 3.1 Navigation and access control (`NAV`)

**OBS-NAV-001 — Splash resolution.**
When the app starts at `/`, the system shall show a black splash (`#000000`, wordmark `مشوار` at
24/700, 24px white spinner) until `isInitializing` becomes false, then redirect to `/login` if
unauthenticated, `/home` if the driver is approved, or `/documents` otherwise.
Evidence: `app_router.dart:39-43, 216-236`.

**OBS-NAV-002 — Public routes.**
While the driver is on `/login`, `/register` or `/otp`, the system shall allow access regardless of
session state (an authenticated driver is not redirected away from the auth funnel).
Evidence: `app_router.dart:21, 46`.

**OBS-NAV-003 — Session guard.**
When any non-public route is requested without a non-empty access token, the system shall redirect to
`/login`.
Evidence: `app_router.dart:50`.

**OBS-NAV-004 — Verification gate.**
While the driver's verification status is not `approved` (pending, rejected or suspended), the system
shall pin navigation to `/documents` and reject every other protected route.
When an approved driver requests `/documents`, the system shall redirect to `/home`.
Evidence: `app_router.dart:51-52`.

**OBS-NAV-005 — Route table.**

| Path | Screen | Shell |
|---|---|---|
| `/` | `SplashScreen` | — |
| `/login`, `/register` | login / driver registration | — |
| `/otp?phone=<e164>` | OTP verification (phone read from query) | — |
| `/documents` | documents + verification status | — |
| `/home`, `/offers`, `/earnings`, `/profile` | top-level sections | yes |
| `/ride-track/:rideId` | trip execution | — (focused) |
| `/earnings/payout-request` | payout request | — (focused) |

Evidence: `app_router.dart:55-92`.

**OBS-NAV-006 — Adaptive shell.**
While the viewport is `< 768` logical px the system shall render a bottom `NavigationBar`; at
`≥ 768` a `NavigationRail` with selected-label; at `≥ 1280` an extended rail with the wordmark `مشوار`.
The shell shall separate itself from content with a single 1px `#E8E8E8` hairline and no elevation.
Evidence: `app_router.dart:135-189`, `ui/core/responsive.dart:10-24`.

**OBS-NAV-007 — Reactive re-routing.**
When auth state changes (login, logout, approval), the system shall re-run the redirect without any
explicit navigation call from the caller.
Evidence: `app_router.dart:26-32`, `app_router.dart:317-321`.

### 3.2 Authentication (`AUTH`)

**OBS-AUTH-001 — Yemeni phone normalization.**
When the driver submits a phone number, the system shall strip non-digits, drop a leading `967` or `0`,
prefix `+967`, and reject input whose normalized length is below `+967` + 7 digits.
Evidence: `login_screen.dart:40-57`, `core/app_constants.dart:35`.

**OBS-AUTH-002 — OTP request.**
When a valid phone is submitted, the system shall `POST /auth/otp/request` and, on success, navigate to
`/otp?phone=<normalized>`. On failure it shall show the state error or `فشل طلب الرمز`.
Evidence: `login_screen.dart:59-68`, `auth_service.dart:9-12`.

**OBS-AUTH-003 — OTP entry.**
The OTP screen shall render exactly `AppConstants.otpLength` (6) single-character numeric cells whose
width is `clamp((availableWidth - 5*8)/6, 40, 64)`, auto-advance focus on input, and refuse submission
unless all 6 digits are present (`أدخل الرمز الكامل من 6 أرقام`).
Evidence: `otp_screen.dart:23-24, 67-71, 135-168`.

**OBS-AUTH-004 — OTP resend cooldown.**
While fewer than 30 seconds have elapsed since the last send, the system shall disable resend and show
`إعادة الإرسال بعد <n> ث`; after the countdown it shall re-enable and call the request endpoint again.
Evidence: `otp_screen.dart:50-63, 89-101, 181-184`.

**OBS-AUTH-005 — Demo prefill.**
Where demo mode is active, the system shall prefill the demo phone and the 6 demo OTP digits and display
a hint that credentials were filled automatically.
Evidence: `login_screen.dart:28-31, 103-110`, `otp_screen.dart:42-47, 123-130`.

**OBS-AUTH-006 — Token persistence.**
When OTP verification succeeds, the system shall persist the access token (and refresh token if present)
in secure storage under `mishwar_driver_access_token` / `mishwar_driver_refresh_token`, then set
`token` and `user` in state.
Evidence: `auth_repository.dart:27-36`, `secure_storage_service.dart:9-33`, `auth_view_model.dart:105-119`.

**OBS-AUTH-007 — Session restore.**
When a stored token exists, the system shall load the driver profile and mark the session
authenticated; `isInitializing` shall be cleared in a `finally` block so the splash never hangs —
including when profile loading throws (`تعذر استعادة الجلسة`).
Evidence: `auth_view_model.dart:64-91`.

**OBS-AUTH-008 — Logout.**
When the driver logs out, the system shall clear both stored tokens and reset state to
`isInitializing: false`, which routes to `/login` without a navigation call.
Evidence: `auth_view_model.dart:147-152`, `app_router.dart:317-321`.

**OBS-AUTH-009 — Driver registration.**
When registering, the system shall require all six fields (name, phone, vehicle type, plate, national
id, licence) plus a valid phone, `POST /drivers/register` with snake_case keys, and on success navigate
to `/login?phone=<normalized>`; on failure show `فشل تسجيل السائق`.
Evidence: `register_screen.dart:44-75`, `auth_service.dart:20-38`.

**OBS-AUTH-010 — Silent failure folding.**
When OTP request, registration or profile load throws, the repository shall return `false`/`null`
rather than propagating, so the UI can only show a generic message.
Evidence: `auth_repository.dart:18-25, 38-59, 61-73`.

### 3.3 Documents and verification (`DOC`)

**OBS-DOC-001 — Document set.**
The system shall model five document types — `nationalId`, `license`, `vehicleRegistration`, `plate`,
`insurance` — each initialized to `pending` with no upload URL.
Evidence: `domain/models/document.dart:4`, `documents_view_model.dart:10-16`.

**OBS-DOC-002 — Aggregate status precedence.**
When computing overall verification status, the system shall return `rejected` if any document is
rejected, else `suspended`, else `pending` (also for an empty set), else `approved`.
Evidence: `domain/models/document.dart:71-77`.

**OBS-DOC-003 — Upload affordance.**
While a document is `pending` and has no upload URL, the system shall show a `رفع` text button;
otherwise it shall show a status pill. A rejected document shall additionally display
`rejectionReason` or `مرفوض — أعد الرفع` in danger colour.
Evidence: `documents_screen.dart:48, 66-86, 147-157`.

**OBS-DOC-004 — Upload is not implemented (honest refusal).**
When `رفع` is tapped, the system shall show `يتم فتح منتقي الملفات (يحتاج حزمة file_picker)` and shall
record `رفع الملفات غير متاح بعد؛ لم يتم رفع المستند`; `uploadDocument()` shall return `false` without
marking the document uploaded.
Evidence: `documents_screen.dart:113-117`, `documents_view_model.dart:27-32`, then `:30` (error text).

**OBS-DOC-005 — Submission refuses without server confirmation.**
When `إرسال للمراجعة` is tapped, the notifier shall return `false` and set
`إرسال المستندات غير متاح بعد؛ لم يتم إرسال أي مستند للمراجعة` — it never reports a submission that the
backend has not confirmed. (The repository layer contradicts this; see D10.)
Evidence: `documents_view_model.dart:34-39`.

**OBS-DOC-006 — Status refresh.**
When `refreshStatus()` runs, the system shall copy the driver's server verification status onto every
document entry and clear the error.
Evidence: `documents_view_model.dart:41-53`.

### 3.4 Home: availability and queue (`HOME`)

**OBS-HOME-001 — Initial queue load.**
When `/home` first builds, the system shall fetch available rides once, after the first frame.
Evidence: `home_screen.dart:21-28`.

**OBS-HOME-002 — Availability toggle.**
When the driver toggles availability, the system shall `PATCH /driver/availability {available: <target>}`;
on success flip `AvailabilityStatus`, on `false` keep the previous status, and on throw keep the previous
status and set `فشل تغيير حالة التوفر`.
Evidence: `home_view_model.dart:58-76`, `ride_service.dart:22-26`.

**OBS-HOME-003 — Connectivity observation.**
The system shall subscribe to `connectivity_plus` on notifier build, map results to
`online|offline|unknown`, and cancel the subscription on dispose. While offline it shall display
`لا يوجد اتصال بالإنترنت` inside the availability panel.
Evidence: `home_view_model.dart:51-55`, `connectivity_service.dart:23-31`, `home_screen.dart:212-226`.

**OBS-HOME-004 — Active-trip continuity strip.**
While `activeRideId` is non-empty, the system shall render an inverted (`#000000`) strip above the
availability panel titled `رحلة نشطة`, with `متابعة` navigating to `/ride-track/<activeRideId>`.
Evidence: `home_screen.dart:36-50, 97-140`.

**OBS-HOME-005 — No going offline mid-trip.**
While a trip is active, the system shall disable the availability toggle, replace its hint with
`لا يمكن تغيير حالة العمل أثناء رحلة نشطة.`, and keep the current status visible.
Evidence: `home_screen.dart:51-59, 198-200, 244-253`.

**OBS-HOME-006 — Queue card content.**
Each available ride shall show a route line (pickup → destination), `<km with 1 decimal> كم · تنتهي بعد
<n> دقيقة` (whole minutes, may be negative once expired), and the fare with 0 decimals followed by
`ريال`; tapping a card opens `/offers`, and tapping is disabled while the driver is offline.
Grid rows use a fixed 88px extent and 1 (mobile) / 2 (tablet, desktop) columns.
Evidence: `home_screen.dart:283-341`, `ui/core/responsive.dart:123-125`.

**OBS-HOME-007 — Manual refresh.**
The section header shall expose a pill action `تحديث` that re-fetches the queue, disabled while loading.
Evidence: `home_screen.dart:61-70`.

### 3.5 Offers / dispatch requests (`OFR`)

**OBS-OFR-001 — Fetch and expiry filter.**
When offers are fetched, the system shall drop client-side any offer whose `expiresAt` is in the past and
replace the list; on throw it shall keep the list and set `فشل جلب العروض`.
Evidence: `offers_repository.dart:12-29`, `offers_view_model.dart:71-80`.

**OBS-OFR-002 — Expiry timers.**
For each fetched offer the system shall schedule one one-shot timer to flip its status to `expired` at
`expiresAt`; all timers shall be cancelled when the notifier is disposed.
Evidence: `offers_view_model.dart:50-61, 82-105`.

**OBS-OFR-003 — Accept guards and idempotency.**
When accepting, the system shall refuse if another ride is active (`لديك رحلة نشطة بالفعل، لا يمكن قبول
رحلة جديدة`) or if the offer is not pending / already expired (`العرض غير متاح للقبول`); otherwise it
shall `POST /offers/<id>/accept` with body `{ride_id}` and an `Idempotency-Key` of the form
`ride_<epochMillis>_<6-digit>`. On success the offer becomes `accepted` and `activeRideId` is set to the
offer's ride.
Evidence: `offers_view_model.dart:65-69, 113-147`, `offers_service.dart:15-21`.

**OBS-OFR-004 — Reject.**
When an offer is rejected, the system shall `POST /offers/<id>/reject` and, on success, mark it
`rejected`; a second reject of the same offer shall fail.
Evidence: `offers_view_model.dart:149-165`, `demo_repositories.dart:200-208`.

**OBS-OFR-005 — Inbox is polled on arrival.**
When `/offers` mounts and no pending unexpired offer is already loaded, the system shall fetch once
after the first frame (push dispatch is not wired; see D4).
Evidence: `offers_screen.dart:31-44`.

**OBS-OFR-006 — Request card.**
Each offer card shall show a countdown ring (`m:ss` above 60s, seconds below; danger colour when
`remaining <= max(10, 20% of window)`), the route, `مدى الرحلة <km> كم`, and the fare as the largest
number on the card. While the offer is actionable, the card shall show an accept-dominant pair —
`قبول` (filled, expanding) and `رفض` (outlined, 104px) — and otherwise a status pill
(`مقبول`, `مرفوض`, `انتهت المدة` for pending-but-expired).
Evidence: `offers_screen.dart` offer card, `ui/core/uber_components.dart` (`UberCountdownRing`).

**OBS-OFR-007 — Active-trip notice replaces the decision.**
While a ride is active, the offers screen shall show `أنهِ الرحلة الحالية قبل قبول طلبات جديدة.` with a
`متابعة` button to the trip screen, and offer cards shall show status pills instead of accept/reject.
Evidence: `offers_screen.dart` (`_ActiveRideNotice`, `_canRespond`).

**OBS-OFR-008 — Active ride release.**
When a trip is completed or cancelled, the trip screen shall call `endActiveRide()`, clearing
`activeRideId` and unblocking the home availability toggle.
Evidence: `ride_tracking_screen.dart:159-169, 179-190`, `offers_view_model.dart:171-173`.

### 3.6 Trip execution (`TRIP`)

**OBS-TRIP-001 — Restore on open.**
When `/ride-track/:rideId` is opened, the system shall load the ride and populate status, pickup,
destination, rider name/phone, start code and `verifiedAssignment` (`driver_assigned == true`); a failure
shall surface `فشل استعادة حالة الرحلة`.
Evidence: `ride_tracking_view_model.dart:74-104`, `ride_repository.dart:43-59`.

**OBS-TRIP-002 — Assignment verification.**
When `تحقق من إسناد الرحلة` is pressed, the system shall call `GET /rides/<id>/verify` and set
`verifiedAssignment` from `verified == true`; a throw shall set `فشل التحقق من الإسناد`.
Evidence: `ride_tracking_view_model.dart:106-115`, `ride_repository.dart:61-68`.

**OBS-TRIP-003 — Start-code gate.**
When starting, the system shall refuse if the assignment is unverified
(`يجب التحقق من إسناد الرحلة أولاً`), if the server supplied no code
(`رمز بدء الرحلة غير متوفر من الخادم`), or if the entered code (trimmed) differs from the server code
(`رمز بدء الرحلة غير صحيح`). On success it shall `POST /rides/<id>/start {start_code}` and set
`started: true`, `status: inProgress`.
Evidence: `ride_tracking_view_model.dart:117-140`, `ride_service.dart:40-44`.

**OBS-TRIP-004 — Completion gate.**
When completing, the system shall require `started && status == inProgress && !completed`; otherwise set
`لا يمكن إنهاء الرحلة في الحالة الحالية`. On success it shall set `status: completed, completed: true`.
Evidence: `ride_tracking_view_model.dart:37-38, 142-157`.

**OBS-TRIP-005 — Cancellation.**
When cancelling, the system shall refuse terminal rides
(`الرحلة مكتملة أو ملغاة مسبقاً`), otherwise `POST /rides/<id>/cancel {reason, actor}` with an
idempotency key and record `RideCancellation(reason, actor, cancelledAt)`. The UI always sends
`actor: 'driver'` and allows an empty reason.
Evidence: `ride_tracking_view_model.dart:159-177`, `ride_service.dart:49-57`, `ride_tracking_screen.dart:171-192`.

**OBS-TRIP-006 — One primary action per phase.**
The trip screen shall present exactly one pinned primary action for the current phase — `تحقق من إسناد
الرحلة` → `بدء الرحلة` (enabled only when the typed code length ≥ the server code length, default 4) →
`إنهاء الرحلة`, and a disabled label (`اكتملت الرحلة` / `الرحلة ملغاة`) once terminal — with a one-line
hint under it, while the destructive `إلغاء الرحلة` control stays in the scroll body.
Evidence: `ride_tracking_screen.dart:88-141`.

**OBS-TRIP-007 — Trip status card.**
The trip screen shall show the phase title (28/700), a connectivity pill (`مباشر` / `غير متصل`), the ride
id, and rows for pickup, destination, rider name and rider phone when present.
Evidence: `ride_tracking_screen.dart:274-354`.

### 3.7 Earnings and payout (`EARN`)

**OBS-EARN-001 — Self-fetching summary.**
When the earnings provider is first read, the system shall defer a fetch to the event loop, start in
`isLoading: true`, and replace state with the returned totals; a throw shall set `فشل جلب الأرباح`.
Evidence: `earnings_view_model.dart:8-29`.

**OBS-EARN-002 — Money presentation.**
The screen shall show `صافي مستحقاتك` as the largest figure (0 decimals + `ريال يمني`) on an inverted
card, then metric rows for total fare, platform commission (`-`), cash collected and platform
receivables (`-`), then a completed-ride grid (84px rows) showing `الرحلة <id>`, completion timestamp
(`toLocal().toString().substring(0,16)`), net to driver and commission.
Evidence: `earnings_screen.dart:26-67, 79-198`.

**OBS-EARN-003 — Payout request.**
When requesting a payout, the UI shall reject non-positive amounts (`أدخل مبلغاً صحيحاً`), otherwise
`POST /earnings/payout-request {amount}`; on success show `تم إرسال طلب التسوية للمراجعة` and return to
`/earnings`; on failure show the state error or `فشل الإرسال`.
Evidence: `payout_request_screen.dart:26-41`, `earnings_service.dart:12-16`.

**OBS-EARN-004 — Available balance shown.**
The payout screen shall display the current `netPayable` as `المتاح للسحب` before the amount field.
Evidence: `payout_request_screen.dart:54-62`.

### 3.8 Error surfacing (`ERR`)

**OBS-ERR-001 — Error envelope exists but is unused.**
The system shall define `ApiException {statusCode, code, messageAr, messageEn, requestId}` and throw it
only when a response body is empty (`EMPTY_RESPONSE`); server error envelopes are never parsed.
Evidence: `dio_client.dart:7-28, 99-114`.

**OBS-ERR-002 — Localized, one-line messages.**
Every view-model shall convert failures into a fixed Arabic string and expose it via `UberErrorText`
(in-page) or `SnackBar`; no error code, request id or stack detail is shown or logged.
Evidence: all `view_models/*`, `ui/core/uber_components.dart` (`UberErrorText`).

**OBS-ERR-003 — No auth-recovery path.**
The system shall not handle `401`/`403`: there is no token refresh call and no forced logout, and
`_AuthInterceptor.onError` simply rejects.
Evidence: `dio_client.dart:132-135`; no `/auth/refresh` call site anywhere.

### 3.9 Demo back end (`DEMO`)

**OBS-DEMO-001 — Override set.** `demoOverrides` shall replace auth, ride, offers, earnings, documents,
map and connectivity providers and set `demoModeProvider: true`.
Evidence: `demo_repositories.dart:305-314`, `main_demo.dart:13-15`.

**OBS-DEMO-002 — Fresh time windows.** Offer and available-ride fixtures shall be regenerated per call so
each fetch gets a fresh expiry window (5 min offers, 10 min available rides).
Evidence: `demo_data.dart:96-141`.

**OBS-DEMO-003 — Full trip state machine.** Demo rides shall enforce verify → start (only `4821`) →
complete, and shall refuse to cancel a completed/cancelled ride.
Evidence: `demo_repositories.dart:83-149`.

**OBS-DEMO-004 — Consistent earnings.** Demo earnings shall be 3 completed rides at 10% commission with
totals 7000 fare / 700 commission / 6300 net / 7000 cash / 700 receivables; payout shall succeed only for
`0 < amount <= 6300`.
Evidence: `demo_data.dart:145-181`, `demo_repositories.dart:213-220`.

**OBS-DEMO-005 — Demo maps.** Place search shall cover 5 Sana'a places, filter by Arabic name or address
(empty query returns all), and provide a synthetic 6-point straight-line route plus a 10-tick location
stream at 2s intervals.
Evidence: `demo_data.dart:39-70, 185-195`, `demo_repositories.dart:254-289`.

**OBS-DEMO-006 — Stable connectivity.** Demo connectivity shall always report `online`.
Evidence: `demo_repositories.dart:294-300`.

**OBS-DEMO-007 — Upload link + submission stub.** Demo documents shall return
`{upload_url: https://demo.invalid/uploads/<type>, method: PUT, expires_in: 900}` and
`submitDocuments() => true`.
Evidence: `demo_repositories.dart:223-251` (see D10 for why the `true` is inconsistent with the notifier).

---

## 4. Observed Non-Functional Requirements

### 4.1 Security

| Observation | Evidence |
|---|---|
| Tokens stored in `flutter_secure_storage`, never in `shared_preferences` (declared, unused) | `secure_storage_service.dart:12`, `pubspec.yaml:22` |
| Bearer token read from storage on every request by an interceptor | `dio_client.dart:119-130` |
| Refresh token persisted but **never used** — no `/auth/refresh`, no rotation | `secure_storage_service.dart:22-28`; no call site |
| Default base URLs are plaintext HTTP (`http://10.0.2.2:4000`, `ws://…`) | `app_constants.dart:18-24` |
| `LogInterceptor` is enabled whenever the base URL contains `localhost` or `10.0.2.2` — i.e. **by default**; `requestHeader` defaults to `true`, so the `Authorization` header is printed to console while request bodies are not | `dio_client.dart:43-46` |
| WebSocket connect passes **no auth token** (and is never called) | `offers_service.dart:26-27` |
| No certificate pinning, no jailbreak/root checks, no biometric lock | absent |
| `Accept-Language` hardcoded to `ar` | `dio_client.dart:37` |

### 4.2 Resilience and performance

| Observation | Evidence |
|---|---|
| Connect and receive timeouts are 15s each | `app_constants.dart:26-27` |
| Retry policy constants exist (`maxRetries: 3`, `retryBaseDelay: 2s`) but **no retry logic consumes them** | `app_constants.dart:29-30` (no call site) |
| No offline write queue; failed writes are simply reported and dropped | repositories fold to `false` |
| Connectivity changes are observed and surfaced on Home only; they do not gate requests | `home_view_model.dart:51-55` |
| One `Timer` per pending offer for expiry; one 1s `Timer.periodic` per visible countdown ring, both cancelled on dispose | `offers_view_model.dart:50-61`, `uber_components.dart` (`UberCountdownRing.dispose`) |
| Long lists use `ListView.separated` (offers) and `GridView` with fixed row extents (home 88px, earnings 84px) rather than intrinsic heights | `offers_screen.dart`, `home_screen.dart:292-298`, `earnings_screen.dart:141-148` |
| Earnings fetch fires on provider read (not on screen mount), so it is shared across screens | `earnings_view_model.dart:10` |

### 4.3 Internationalisation and RTL

- Default locale `ar_YE`; `en_US` is accepted by `localeResolutionCallback` (`main.dart:29-39`).
- A **complete, translated catalogue exists** — `lib/l10n/app_ar.arb` and `app_en.arb`, 76 lines each,
  ~70 keys including English copy — but it is dead: there is no `l10n.yaml`, `generate: true` is absent
  from `pubspec.yaml`, and no screen references generated `AppLocalizations`. Every visible string is an
  inline Arabic literal (D16).
- Directionality is inherited from the locale (RTL); layouts use `EdgeInsetsDirectional`, `AlignmentDirectional`
  and `textAlign: end` so mirroring does not need per-widget branches (`ui/core/uber_components.dart`).
- All user-facing copy is inline Arabic literals inside widgets/notifiers.

### 4.4 Design system and responsiveness

- Tokens: true black `#000000`, white `#FFFFFF`, body gray `#4B4B4B`, muted `#AFAFAF`, chip `#EFEFEF`,
  hairline `#E8E8E8`, one reserved `danger #D32F2F` (+ surface `#FDECEA`); 999px pills on every button;
  8/12px card radii; whisper shadows; no gradients; active/inverse state = black inversion.
  Evidence: `ui/core/app_theme.dart`, `ui/core/uber_components.dart`.
- Minimum interactive height 44px (`minimumSize: Size(0, 44)`, `MaterialTapTargetSize.padded` ⇒ 48px
  layout height). Evidence: `app_theme.dart` elevated-button theme.
- Breakpoints `375 / 768 / 1280`; screen paddings 16 / 24 / 32; content capped at
  480 (auth, profile), 560 (register, payout), 720 (trip, documents), 900 (home, earnings).
  Evidence: `ui/core/responsive.dart:10-24, 72-96`.
- Overflow is a tested contract: every screen is pumped at 375×700, 768×1024 and 1280×800 and must not
  throw (`test/responsive_layout_test.dart`).

### 4.5 Testability

- All data access is behind Riverpod providers, so every collaborator is replaceable by
  `overrideWithValue` — the pattern used by both the demo entry point and every test.
- Mockito is used **without** `build_runner`: mocks are hand-written with nullable widening so `any`
  matchers type-check (`test/*_notifier_test.dart` headers).
- `integration_test` is declared but no integration test file exists.

---

## 5. Inferred Acceptance Criteria

Each criterion below is derived from an existing test, i.e. it is executable today.

**AC-001 — Session restore never hangs the splash**
Given a stored access token, When the profile request throws, Then `initialize()` returns false,
`isInitializing` is false and the error is `تعذر استعادة الجلسة`. (`auth_notifier_test.dart:131-143`)

**AC-002 — Logout does not re-show the splash**
Given an authenticated driver, When they log out, Then `isAuthenticated` and `user` are cleared and
`isInitializing` is false. (`auth_notifier_test.dart:158-173`)

**AC-003 — Availability toggle is optimistic only on success**
Given the driver is offline, When the availability call throws, Then availability stays `offline` and the
error is `فشل تغيير حالة التوفر`. (`home_notifier_test.dart:77-89`)

**AC-004 — Queue load clears loading**
Given a non-empty available-ride list, When `fetchAvailableRides()` completes, Then the list is populated
and `isLoading` is false. (`home_notifier_test.dart:91-109`)

**AC-005 — One active ride at a time**
Given an accepted offer, When a second offer is accepted, Then it fails with
`لديك رحلة نشطة بالفعل، لا يمكن قبول رحلة جديدة`. (`demo_data_test.dart:128-135`, `offers_notifier_test.dart:82-92`)

**AC-006 — Expired offers cannot be accepted**
Given an offer whose `expiresAt` is in the past, When accepted, Then it fails with `العرض غير متاح للقبول`.
(`offers_notifier_test.dart:111-129`)

**AC-007 — Rejection is single-shot**
Given an offer already rejected, When rejected again, Then the operation fails.
(`demo_data_test.dart:137-144`)

**AC-008 — Start requires verification**
Given an unverified assignment, When `startRide('1234')` is called with the correct code, Then it fails
and the error mentions `التحقق`. (`ride_tracking_notifier_test.dart:54-65`)

**AC-009 — Wrong start code is rejected locally**
Given a verified assignment with server code `1234`, When `startRide('9999')` is called, Then it fails and
the error mentions `غير صحيح` — no network call is made. (`ride_tracking_notifier_test.dart:67-78`)

**AC-010 — Correct code starts and unlocks completion**
Given a verified assignment and the correct code, When started, Then `started` is true, status is
`inProgress` and `canComplete` is true. (`ride_tracking_notifier_test.dart:80-94`)

**AC-011 — Terminal rides cannot be cancelled**
Given a completed ride, When cancelled, Then it fails with `الرحلة مكتملة أو ملغاة مسبقاً` and the
cancellation is not recorded. (`demo_data_test.dart:174-199`)

**AC-012 — Cancellation records reason and actor**
Given an assigned ride, When cancelled with `actor: 'driver'`, Then status is `cancelled` and
`cancellation.actor == 'driver'`. (`ride_tracking_notifier_test.dart:107-119`)

**AC-013 — Earnings totals match the ledger**
Given the demo ledger, When the earnings provider is read, Then 3 rides, `totalFare 7000`,
`netPayable 6300`, `isLoading` false. (`demo_data_test.dart:148-158`)

**AC-014 — Payout bounds**
Given net payable 6300, When requesting 1000 / 0 / 999999, Then the results are true / false / false.
(`demo_data_test.dart:160-165`)

**AC-015 — Every screen survives three viewports**
Given any screen, When rendered at 375×700, 768×1024 and 1280×800, Then no exception is thrown and the
nav shell swaps bottom bar ↔ rail. (`responsive_layout_test.dart`)

**AC-016 — Primary buttons are ≥ 44px tall**
Given the login screen at 375×700, When measured, Then the primary `ElevatedButton` height is ≥ 44.
(`responsive_layout_test.dart`)

---

## 6. Known Defects and Internal Contradictions

Severity reflects user impact in the live (non-demo) path. These are **observed**, not speculative.

| ID | Sev | Defect | Root cause / evidence | Impact |
|---|---|---|---|---|
| **D1** | High | A trip restored from the server can never be completed | `ride_repository.dart:48-59` never maps `started`/`completed`; `_restore()` (`ride_tracking_view_model.dart:88-104`) sets `status: inProgress` but leaves `started: false`; `canComplete` requires `started` (`:38`). The new single-CTA UI then offers `بدء الرحلة` again (`ride_tracking_screen.dart:122-128`) | Driver stuck mid-trip after any app restart or deep link; server would reject a re-start |
| **D2** | High | No active-ride restore at startup | `activeRideId` is memory-only (`offers_view_model.dart:20`); no `GET /rides/active` call exists; `docs/user-flows.md:50` mandates it | After a crash/restart the driver loses the trip, the home strip, and the offline lock |
| **D3** | High | Invalid/expired session lands in the documents gate instead of login | `auth_repository.dart:61-73` folds `loadMe` failure to `null`, `initialize()` keeps the token (`auth_view_model.dart:64-91`), so `isAuthenticated && !isApproved` ⇒ redirect `/documents` (`app_router.dart:51`). No 401 handling, no refresh | Approved driver is shown "your documents are under review" and cannot recover except by manual logout |
| **D4** | High | Real-time dispatch is dead code | `OffersService.connectOffersWebSocket()` (`offers_service.dart:26-27`) has **zero call sites**; also connects without a token | Offers only appear if the driver opens/refreshes the tab; `docs/user-flows.md:41` requires a push |
| **D5** | Med | API contract drift (see §7) | Services vs `docs/api-specification.md` | Client and server disagree on paths, verbs, bodies, and money encoding |
| **D6** | Med | Money handled as `double` | `Offer.fare`, `Ride` (no fare), `EarningsState.*` doubles; wire parsed via `as num?`; formatted with `toStringAsFixed(0)`; ADR-0005 requires decimal strings | Rounding loss on non-integer fares; contract violation |
| **D7** | Med | Server error envelope never parsed | `ApiException` built only for `EMPTY_RESPONSE` (`dio_client.dart:99-114`); repositories use `catch (_)` | Users get generic Arabic text; no `code`/`request_id` for support |
| **D8** | Med | Idempotency is partial | `_IdempotencyInterceptor` is a no-op (`dio_client.dart:138-143`); keys only on offer-accept and ride-cancel | `startRide`/`completeRide`/payout are unsafe to retry |
| **D9** | Med | `acceptOffer` can throw instead of returning false | `orElse: () => throw StateError('العرض غير موجود')` sits outside the `try` (`offers_view_model.dart:118-121`) | A vanished offer (race with expiry/refresh) escapes the boolean contract and can surface as an unhandled async error |
| **D10** | Med | Document submission layers disagree | `documents_repository.dart:15-21` returns `true` with no network call; `documents_view_model.dart:34-39` refuses; `demo_data_test.dart:224` asserts the `true` | The repository advertises success for work nobody performed; the test locks the false positive in |
| **D11** | Low | Declared capabilities are unused | `mapApiKey`, `maxRetries`, `retryBaseDelay` (`app_constants.dart:29-40`); `StubMapService` is the only implementation (`map_service.dart:47-66`); `mapRepositoryProvider` has no UI consumer; `web_socket_channel` and `shared_preferences` unused | Misleading `pubspec`/config; no map, no retry despite the constants |
| **D12** | Low | Trip connectivity pill is permanently `غير متصل` | `RideTrackingState.isConnected` is never assigned true (`ride_tracking_view_model.dart:33`); rendered at `ride_tracking_screen.dart:309-312` | Live trips look disconnected |
| **D13** | Low | Dead earnings field on Home | `HomeState.earningsSummary` never set; `fetchEarningsSummary()` is an empty method (`home_view_model.dart:20, 88-94`) | Home cannot show today's earnings |
| **D14** | Low | Phone passed to `/login` is ignored | `register_screen.dart:69` navigates to `/login?phone=…`; `app_router.dart:57-58` builds `LoginScreen()` without reading the param | Driver re-types the number they just entered |
| **D15** | Low | A screen lives in the router | `ProfileScreen` is declared in `app_router.dart:239-368` | Layering violation; the routing file owns UI and its copy |
| **D16** | Low | Translation catalogue is complete but unwired | `lib/l10n/app_ar.arb` + `app_en.arb` hold ~70 translated keys; no `l10n.yaml`, no `generate: true`, no `AppLocalizations` usage anywhere in `lib/ui` | English is fully translated yet unreachable — selecting it yields an Arabic UI |
| **D17** | Low | Offer state hygiene | A re-fetch does not cancel timers for offers that disappeared (`offers_view_model.dart:82-96`); `copyWith` cannot clear `selectedOffer` (`:28-46`) | Transient stale timers; `selectedOffer` survives `endActiveRide` |
| **D18** | Low | Client duplicates server filtering | `/rides/available` and offers both filtered by `isExpired` in repositories (`ride_repository.dart:26`, `offers_repository.dart:27`) | Expiry windows become client-clock dependent |
| **D19** | Low | Auth funnel reachable while signed in | `_publicRoutes` short-circuits the guard (`app_router.dart:46`) | A signed-in driver can re-enter OTP and overwrite the session |
| **D20** | High | A release build cannot reach the network | `INTERNET` is declared only in `android/app/src/debug/AndroidManifest.xml:6`; `android/app/src/main/AndroidManifest.xml` declares no permissions | Debug/demo builds pass while the shipped APK fails every request at the socket layer |
| **D21** | High | No location permission | main manifest declares no `ACCESS_FINE_LOCATION`/`ACCESS_BACKGROUND_LOCATION`; `RideService.updateLocation` (`ride_service.dart`) and `HomeState.lastLocationUpdate` exist, but nothing in the app can produce a coordinate | Driver position, map centring and dispatch proximity are all non-functional |
| **D22** | High | No keep-alive or background execution | no `FOREGROUND_SERVICE*` permission, no `<service>`, no background package in `pubspec.yaml:7-19`; all work runs inside Riverpod providers bound to a widget tree | Offers, trip timers and location reporting stop as soon as the app is backgrounded — the normal state for a driver working a shift |
| **D23** | Low | Committed map key contradicts the setup doc | key inlined at `android/app/src/main/AndroidManifest.xml:29`; `README-SETUP.md:24` states it must not be in the repository | Demo key sits in git history; needs rotation and package/SHA-1 restriction |

---

## 7. API Contract Drift (`driver_app` services vs `docs/api-specification.md`)

The client uses no `/v1` prefix and diverges from the written contract in the following places.

| Capability | Client (observed) | Contract (`docs/api-specification.md`) | Verdict |
|---|---|---|---|
| Base path | `http://10.0.2.2:4000` + `/auth/...` | `/v1` prefix | Drift |
| OTP request / verify | `POST /auth/otp/request`, `POST /auth/otp/verify` | same paths | OK (prefix aside) |
| Refresh / logout | absent | `POST /auth/refresh`, `POST /auth/logout` | Missing |
| Driver profile | `GET /drivers/me` | `GET/PATCH /me` | Drift |
| Registration | `POST /drivers/register` | `POST /driver/profile`, `POST /driver/vehicles` | Drift |
| Availability | `PATCH /driver/availability` | `PUT /driver/availability` | Verb drift |
| Location ping | `POST /driver/location {latitude,longitude}` | same + `recorded_at` | Missing field |
| Available rides | `GET /rides/available` | not defined (dispatch uses `GET /driver/offers`) | Undefined endpoint |
| Offers list | `GET /offers` | `GET /driver/offers` | Drift |
| Accept / reject | `POST /offers/{id}/accept {ride_id}`, `POST /offers/{id}/reject` | same | OK |
| Assignment verify | `GET /rides/{id}/verify` | not defined (`driver_assigned` on `GET /rides/{id}`) | Undefined endpoint |
| Start ride | `POST /rides/{id}/start {start_code}` | `POST /rides/{id}/start {code}` | Field drift |
| Complete / cancel | `POST /rides/{id}/complete {}`, `POST /rides/{id}/cancel {reason,actor}` | same paths; actor implied by token | Body drift |
| Active ride | absent | `GET /rides/active` | Missing (see D2) |
| Earnings | `GET /earnings` | `GET /driver/earnings` | Drift |
| Payout | `POST /earnings/payout-request {amount}` | `POST /driver/payout-requests` | Drift |
| Documents | `POST /documents/upload-link`, `POST /documents/submit` | `POST /driver/documents` (signed links) | Drift |
| Money | `num` (float) | decimal strings `"1500.00"` + `currency` | Drift (D6) |
| Errors | `ApiException` unused for envelopes | `{error:{code,message_ar,message_en,request_id}}` | Drift (D7) |
| Realtime | `ws://…/ws/driver/offers`, unauthenticated, unused | authenticated socket; events `offer.created|expired`, `ride.updated`, `driver.location` | Drift (D4) |

---

## 8. Uncertainties and Questions

- [ ] **Which backend is authoritative** for the driver API — NestJS `apps/api` or `api_go`
      (`docs/codebase/CONCERNS.md:9`)? The client's paths match neither contract, so "fix the client"
      and "fix the contract" are both plausible.
- [ ] **Is `driver_assigned` guaranteed** on `GET /rides/{id}` after restart, or must the client call
      `/verify`? This decides whether D1's fix is client-only.
- [ ] **Who owns active-ride recovery** — should the client call `GET /rides/active` on splash and seed
      `activeRideId`, or is that state pushed over WS only?
- [ ] **Money encoding**: will the server send decimal strings (ADR-0005) or numbers (as the client
      parses today)? This drives whether to introduce a `Money` value type.
- [ ] **Documents upload**: is a direct-to-storage PUT intended (`upload_url` + `method` + `expires_in`
      suggest yes), and which package will be used (`file_picker` is referenced only in a snackbar)?
- [ ] **Approval source of truth**: `/documents` polls `loadMe`; there is no push/socket for
      `driver.approved`. Should approval arrive over WS, or via refresh-on-focus?
- [ ] **English**: is `en_US` a shipping requirement or just a locale placeholder?
- [ ] **Map provider for Sana'a** (Google vs Mapbox vs OSM) — `google_maps_flutter` is declared and the
      Android key is inlined, but `MapService` is a stub whose only implementation throws
      `UnimplementedError`. `README-SETUP.md` exists but describes a module layout the codebase does not
      contain (`lib/core/map_provider.dart`, `StubMapProvider`); the real files are
      `data/services/map_service.dart` and `data/repositories/map_repository.dart`.
- [ ] **Cancel policy**: the UI allows an empty reason and hardcodes `actor: 'driver'`; the lifecycle doc
      requires a reason for every cancellation (`docs/user-flows.md:24`).

---

## 9. Recommendations

**P0 — correctness of the live trip lifecycle**

1. Map the full ride state on restore: derive `started`/`completed` from `status` and hydrate
   `cancellation` (fixes D1). Add a regression test: restore a `in_progress` ride ⇒ `canComplete` is true.
2. Add `GET /rides/active` on splash; seed `activeRideId` (or drop the dependency by deriving the strip
   from the restored ride) so a restart resumes the trip (D2).
3. Handle `401`/`403` centrally in `DioClient`: clear tokens, reset auth state, route to `/login`. Either
   implement `/auth/refresh` with rotation or delete the stored refresh token (D3).
4. Wire dispatch push: authenticate the socket, consume `offer.created` / `offer.expired`, and keep the
   HTTP fetch as the reconciliation fallback (D4).

**P1 — contract and error fidelity**

5. Write the wire contract once (`packages/api_contracts` → OpenAPI), then align paths/verbs/bodies from
   §7 and add `Idempotency-Key` to every non-idempotent write (D5, D8).
6. Parse the standard error envelope into `ApiException` and surface `message_ar` + `request_id` in
   debug logs and support flows (D7).
7. Introduce a `Money` value type (integer minor units) and stop `toStringAsFixed(0)` rounding of fares
   (D6).
8. Make `acceptOffer` return `false` for unknown offers instead of throwing, and add the missing test
   (D9).
9. Resolve the documents contradiction: delete `DocumentsRepository.submitDocuments()`'s unconditional
   `true`, and update `demo_data_test.dart:224` accordingly (D10).

**P2 — hygiene**

10. Delete or implement the unused capabilities: `mapApiKey`, `maxRetries`/`retryBaseDelay` (retry with
    backoff + `retry-after`), `StubMapService`, `shared_preferences`, `intl`/English locals (D11, D16).
11. Assign `isConnected` from the socket/telemetry state, or remove the pill (D12).
12. Move `ProfileScreen` into `ui/features/profile/views/` (D15); read the `phone` query param on login
    (D14); stop treating public routes as public when authenticated (D19).
13. Harden logging: disable `requestHeader` on `LogInterceptor` even for local hosts (token leak to
    console / crash reports).
14. Add widget tests for the offers inbox and trip screen (accept/reject, countdown expiry, single-CTA
    phase transitions); only the three notifier suites and the responsive shell are covered today.

---

## 10. Verification Status

- Compile gate: `flutter analyze` → **no issues** (after the driver UI work described in §11).
- Behaviour gate: **green.** `flutter test --reporter compact` over the full `apps/driver_app/test`
  directory ran to completion in 1m07s and ended `+76: All tests passed!` — 76 tests across all 7 files
  (`responsive_layout_test`, `home_notifier_test`, `earnings_notifier_test`, `demo_data_test`,
  `offers_notifier_test`, `ride_tracking_notifier_test`, `auth_notifier_test`), zero skipped, zero failures.
  Re-run with: `cd apps/driver_app && flutter test --reporter compact`.
- No runtime/manual verification was performed against a live backend: every behaviour in §3 that depends
  on the server (§3.1 guards, §3.2 network paths, §7 contracts) is evidenced by source only, not by
  execution. Acceptance criteria AC-001…AC-016 are the executable subset that was actually run.

## 11. Change Context (why some requirements look new)

The requirements in §3.4–§3.6 (countdown ring, dominant accept, auto-fetch, active-trip strip, offline
lock, single pinned CTA, `endActiveRide()`) were introduced in the immediately preceding UI pass, derived
from an analysis of the production Uber Driver app. They are implemented and analyzer-clean but are not
covered by tests yet (§9.14).
