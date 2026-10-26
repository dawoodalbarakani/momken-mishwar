# Black-Box Specification: Uber Driver (`com.ubercab.driver`)

> **Scope of this document.** What the Uber Driver app does, and how it is built, derived **only** from
> sources Uber publishes deliberately: the Google Play listing, and Uber's own ten-part engineering series
> on how the app was rewritten. No APK was downloaded, unpacked, or decompiled.
>
> **Why the binary was not analysed.** Decompiling a proprietary app sits under anti-circumvention law in
> most jurisdictions, breaches the Play/ToS terms, and the only sources for a direct APK are third-party
> mirrors — untrusted binaries that would enter a repository owned by a competing operator. The cost/benefit
> is also poor on the merits: see §6, where the same information is shown to be available from documentation
> and to already be actionable against our own codebase.
>
> **Evidence discipline.** Every claim is tagged `[P]` published fact with a citation, or `[I]` inference
> drawn from published facts. Nothing here is `[P]` unless a source is listed in §1. Requirements observed in
> **our** app are cited by defect id (`D1`…`D23`) against
> [`specs/driver_app_reverse_spec.md`](./driver_app_reverse_spec.md).

---

## 1. Evidence corpus

| # | Source | Date | What it yields |
|---|---|---|---|
| E1 | [Play listing — Uber ‑ Driver: Drive & Deliver](https://play.google.com/store/apps/details?id=com.ubercab.driver) | updated 2026‑10‑16 | Market position, published feature set, data-safety declarations, changelog text, review themes |
| E2 | [How Uber's New Driver App Overcomes Network Lag](https://www.uber.com/us/en/blog/driver-app-optimistic-mode/) | 2018‑11‑28 | **Optimistic Mode**: offline request model, transforms, restart persistence |
| E3 | [Scaling Cash Payments in Uber Eats](https://www.uber.com/rs/en/blog/driver-app-cash-payments/) | 2018‑12‑12 | Cash-first economy: arrears netting, **offline 4-digit code exchange**, hashing, abuse limits |
| E4 | [Building a Real-time Earnings Tracker](https://www.uber.com/rs/en/blog/real-time-earnings-tracker/) | 2019‑03‑25 | Push-first earnings, card schema, staleness/outage handling, mobile ranking |
| E5 | [Activity/Service as a Dependency](https://www.uber.com/rs/en/blog/activity-service-dependency-android-app-architecture/) | 2019‑05‑29 | RIBs structure, Activity-independent core, **single keep-alive service**, and its compromises |

E5 carries the canonical index of the rewrite series ("Carbon"), which also covers: why they rewrote it,
RIBs, shipping a rewrite as a dual binary, the driver map interface, Beacon (24-bit RGB rider-driver
matching), and a server-driven driver-preferences platform.

---

## 2. Observable product surface

### 2.1 Market position `[P]`

| Attribute | Value |
|---|---|
| Rating / reviews | 4.6★ · 6.39M reviews |
| Installs | 100M+ |
| Category rank | #8 top free, Business |
| Content rating | Everyone · *Users Interact, Shares Location* |
| Data safety | Collects **Location, Personal info and 9 others**; may share Personal info, Financial info and 3 others; encrypted in transit; deletion requestable |

The platform is **two apps sharing one shell**: rideshare driving and delivery (food, grocery, packages,
alcohol, catering). Switching between them is a mode change, not a second install.

### 2.2 Published capability set `[P]`

- **Dispatch:** accept trip requests in-area; **upfront fare and trip details shown before accepting**.
- **Guided demand:** in-app heatmap, Earning Trends, and Opportunities indicate where/when to go online.
- **Earnings:** Instant Pay (cash out anytime), tips retained 100%, "Tip Guarantee" protecting delivery
  tips post-drop-off, Quests and Boost+ promotions surfaced in a **Discover tab**.
- **Tiering:** Uber Pro (Gold/Platinum/Diamond) and Uber Eats Pro unlock priority dispatch and benefits.
- **Safety:** "Record My Ride" audio recording, Women Rider Preference, 24/7 live in-app support.
- **Automotive:** full CarPlay and Android Auto integration.
- **Protocol detail published by Uber:** the app uses **full-screen notifications to present incoming VoIP
  calls** between rider and driver so the driver can accept/decline and talk in real time.
- **Operational footnote published by Uber:** ~2 GB of data per month, battery cost from navigation, and
  machine-translated content "per device settings".

### 2.3 Changelog and review signal `[P]`

The Play changelog is boilerplate ("several bug fixes and performance improvements") — Uber does not
disclose feature changes there. The top-voted reviews (1.5k–2.7k "found this helpful" each) cluster on three
complaints that are architectural, not cosmetic:

1. **Account/trust enforcement** — "flagged multiple times for suspicious activity", payment edits paused,
   secondary-device login blocked.
2. **Dispatch fairness** — repeatedly receiving distant low-value trips, with rating damage as the penalty.
3. **Cancellation economics** — flat-rate blocks lost when the counterparty fails, with no support recovery.

*Reading:* the differentiator is not UI, it is the **decision layer** (what gets offered to whom) plus
**trust/device posture** and **dispute recovery**. Copying screens without those three buys nothing.

### 2.4 Platform behaviour inferred from published features `[I]`

| Published feature | Inferred platform requirement |
|---|---|
| "Shares Location", navigation, heatmap | Background location while online, surviving screen-off |
| Full-screen-intent VoIP call | `USE_FULL_SCREEN_INTENT`, a ringing UI independent of the activity, plus push wake-up |
| "Record My Ride" audio | Microphone capture during a trip, likely with a foreground service type for it |
| Offers must arrive while the app is closed | A process that outlives the UI — see §3.1 |
| ~2 GB/month, navigation battery cost | Continuous location + tile streaming + socket, i.e. permanently online |

---

## 3. Internals, as Uber documents them

### 3.1 A core that does not depend on the UI `[P]` (E5)

The rewrite ("Carbon", designed 2017, rolled out September 2018) rests on two principles:

1. **Services are not a structural component.** All service code fits in a **single ~100-line file** whose
   only job is to keep the app alive and restart it if the OS reclaims memory. Features request that
   behaviour by incrementing/decrementing a **`KeepAliveCount`**; above zero the sticky foreground service
   runs, at/below zero it dies. Uber's stated reason: the previous multi-Service design duplicated every
   surface (foreground *and* background variants of offers, of VoIP), popped heads-up notifications on every
   foreground switch, and scattered the "how long may we drain battery" logic across files.
2. **Activities are optional.** The core hierarchy (`Online` RIB, `Navigation` RIB) attaches regardless of
   whether an Activity exists. When an offer arrives with no Activity, the `Offer` RIB attaches to a window;
   with an Activity, the same RIB attaches to `OnlineView`. The RIB observes a stream of View objects emitted
   by the App Root to know which case it is in.

Structure is **RIBs** — each unit is Interactor (logic) + Router (navigation) + Builder (dependency),
attachable as a child of another RIB.

Acknowledged costs, in Uber's words: unconventional and needs strict conformance; engineers must reason about
background behaviour for features that never appear in the background; and RIBs outliving their Views create
a new leak class because Views are emitted reactively.

### 3.2 Optimistic Mode: the trip state machine runs ahead of the network `[P]` (E2)

Motivating scenario, verbatim from Uber: a driver at a crowded airport in Bangalore, cash trip, no
connectivity at the curb — with the old app they could not close the trip, so they drove further down the
terminal to find signal, extending the trip. Uber's earlier mitigation (batching failed requests) "wasn't
able to intelligently update the state, stack multiple actions, or persist state across sessions."

Four components:

| Component | Behaviour |
|---|---|
| **Optimistic request** | A request that can **serialise/deserialise to disk**, like a normal request, and is paired 1:1 with a transform |
| **Optimistic transform** | A pure state→state function producing the state the server *will* return. Transforms **stack**, applying in order as an object passes through |
| **Optimistic stream** | An RX stream is the message bus; the latest server state + all pending transforms = the state the feature renders. Transforms are applied before publish, so the UI reacts only to the optimistic state |
| **Dependent requests** | Requests that presuppose an earlier optimistic request ("it wouldn't make sense to end a trip the backend doesn't know has started") are **queued** until their predecessor syncs; if the wait exceeds a bound they fail with a network error |

Three hard problems they call out:

- **Rebasing** — if a stale server snapshot (count = 1) arrives while two increments are unsynced, the
  transforms are re-applied on top of the fresh snapshot so the UI does not oscillate between states.
- **Restart survival** — pending optimistic requests *and* the last optimistic state are persisted; on
  relaunch they load and the queue resumes syncing.
- **Error surfacing** — rare server rejections must unwind an optimistic state that was already shown.

Measured effect as of Nov 2018: start-trip and end-trip were the first two operations converted, saving
**~13.5 s per optimistic operation**, aggregating to over a year of driver time per day. Later extended to
Eats cash drop-offs, ratings, and message read-state.

### 3.3 A cash economy that settles offline `[P]` (E3)

The relevant market description is direct: in cash-first markets, "credit and debit cards are not
commonplace", so cash payment was extended across India, Latin America, and **Africa**, and the same
constraint drove the delivery design because "many cash payment-enabled markets have unreliable network
connectivity [and] the cash exchange operation needed to function entirely offline."

Rides model: the driver **keeps the cash** and owes Uber its fee; dispatch deliberately allocates enough
digitally-paid trips to net out fees owed from prior cash trips. Delivery has the harder problem — most cash
an eater hands over is owed to the restaurant — so they built **restaurant arrears collection** as its own
microservice that: decides trip eligibility, computes suggested amounts, **maintains cash-drop state with a
state machine**, and supplies display data to driver and restaurant apps.

The offline exchange, which is the transferable idea:

1. At dispatch, the restaurant is given a **randomly generated four-digit code**.
2. The mobile client is sent only the **SHA-256 salted hash** of that code.
3. The driver keys in the code on the phone; the client hashes it and **compares hashes entirely offline**.
4. Abuse controls: **rate limiting**, a **maximum attempt count**, and **expiry** of the cash option after a
   reasonable duration. Inconsistencies are investigated server-side, with bans as the backstop.
5. The confirmation is written optimistically and replayed when connectivity returns; driver credited,
   restaurant balance adjusted against future digital earnings.

Both parties acknowledging a real-world handover is the fraud model — not a server round-trip.

### 3.4 Earnings as a pushed, versioned feed `[P]` (E4)

Uber replaced pull-per-trip (which caused outages under load and inconsistent numbers across touchpoints)
with a **push-first** framework, and made data consistency an explicit architectural goal.

- A **Realtime-API Gateway** is the single source of truth for tracker cards, reachable by push or HTTP pull.
- `TrackerCard` schema carries the staleness controls that make caching safe: `cardID` (identity),
  `priority` + `statusModePriority` (mobile ranking), `isValid`, `payload`, `cardType`
  (`BROWSE`/`BULLETIN`/`BOTH`), **`expiresAt`**, **`lastUpdatedAt`**, `outageState`,
  `shouldForceSwitchStatusMode`.
- **Expiry is lazy on purpose**: services set `expiresAt` rather than pushing expiry events, because
  simultaneous expiry pushes would load-spike the backend.
- `lastUpdatedAt` is what the client displays **while the backend is in outage and card data is cached
  locally** — the user is told the number is old instead of being shown a stale number as if fresh.
- UI is three modes — **Status** (current trip earnings, on-screen card), **Browse** (daily/weekly summary,
  last trip, history), **Bulletin** (milestones, "your last trip was processed") — built as four RIBs plus a
  per-card plugin so a card can be switched off without touching core.
- Client-side core logic lives in `TrackerDataManager`: takes per-domain streams (`RealtimeEarningsManager`,
  `RealtimeIncentiveManager`), aggregates/ranks/validates, and fans out into three mode streams. Managers are
  **singletons in active scope**, self-contained for pull+push.
- Adoption signal: **86% of drivers use it on days they pick up riders**; Driver "Privacy Mode" hides
  real-time earnings on the home screen.

---

## 4. Gap analysis against `driver_app`

Mechanisms Uber documents, placed against what our code actually does.

| # | Uber mechanism `[P]` | Our implementation `[P]` (spec + code) | Verdict |
|---|---|---|---|
| G1 | Trip actions are optimistic **and persisted**; state survives restart and resyncs (E2) | `activeRideId` is in-memory (`offers_view_model.dart:20`); failed writes fold to `false` and are dropped (spec §4.2); no queue, no persistence | **Absent.** Exactly the airport scenario — a driver in a Sana'a dead zone cannot close a cash trip |
| G2 | Restored trip is authoritative: status alone is enough to continue (E2) | `_rideToDomain` never maps `started`; `_restore()` yields `inProgress` + `started: false`; `canComplete` requires `started` (`D1`) | **Broken.** Restore produces an uncompletable ride |
| G3 | Active work is recoverable after process death (E2, `KeepAliveCount`) | no `GET /rides/active` call exists (`D2`); no keep-alive service at all (`D22`) | **Absent.** A restart loses the trip, the home strip, the offline lock, and all dispatch |
| G4 | Core runs with **no Activity** attached (E5) | every behaviour lives in a Riverpod provider bound to a widget tree; no foreground service, no background package (`pubspec.yaml:7-19`) | **Absent.** Offers/timers/location stop on background — the driver's normal state |
| G5 | One keep-alive gate (`KeepAliveCount`) so battery logic is reviewable in one file (E5) | no lifecycle policy exists to centralise | **Absent** (moot until D22 is fixed) |
| G6 | Handover proof is a **salted hash compared offline**, with rate limit + max attempts + expiry (E3) | `startCode` travels in the ride payload as plaintext; the notifier compares it client-side (`AC-009`), then calls the server | **Weaker and online-dependent.** Genuine security + offline upgrade |
| G7 | Cash arrears have their own **state machine** + netting against digital earnings (E3) | `CompletedRide` already carries `fare`, `platformCommission`, `netToDriver`, `cashCollected` — the float is modelled, but there is no arrears/settlement state machine or UI | **Half-built.** Domain model right, lifecycle missing |
| G8 | Earnings are **push-first** with `expiresAt` / `lastUpdatedAt` / `outageState` (E4) | pull-only `GET /earnings` fired on provider read (`earnings_view_model.dart:10`); one screen; `HomeState.earningsSummary` never populated (`D13`) | **Absent** |
| G9 | Card feed is extensible via payload + ranking, so new earn types ship without touching core (E4) | `EarningsState` is one fixed aggregate; no card/envelope model | **Absent.** Every new earn type is a schema change |
| G10 | Upfront fare + trip details before accept (E1) | fare shown on offer card (`OBS-OFR-006`) | **Parity** |
| G11 | Availability = a durable online state, not a toggle in RAM (E1, E5) | `HomeState.availability` in memory; `PATCH /driver/availability` on toggle | **Partial.** Server knows, client forgets on restart |
| G12 | Background location while online (E1, §2.4) | **no location permission declared**; `RideService.updateLocation` can never receive a fix (`D21`) | **Absent.** Blocks map, proximity dispatch, and trip progress |
| G13 | Shippable release build (E1 — 100M installs) | `INTERNET` declared only in the debug manifest (`D20`) | **Broken.** Release APK cannot reach any API |
| G14 | Trust/device posture + dispute recovery drive rating sentiment (§2.3) | no device-attestation concept; support is an error string | **Absent** (deliberate scope decision, but note the sentiment driver) |

**Reading of the table:** our app reproduces Uber's *screens* (§G10, partly G11) and almost none of its
*trip-continuity and cash apparatus* (G1–G9), while failing three platform-level preconditions (G12–G13)
that no amount of UI work can compensate for. That is the honest summary of the competitive gap.

---

## 5. Three designs worth adopting

### 5.1 Persisted trip state machine + optimistic queue  → closes D1, D2, D22, G1–G5

Adapt E2 to Flutter/Riverpod without inventing a framework:

- Replace `activeRideId: String?` with a `RideSession` record persisted via `shared_preferences` (already a
  dependency, currently unused): `{rideId, phase, startCodeHash, acceptedAt, lastServerSnapshotAt}`.
- Model phase as an explicit enum — `assigned → verified → started → completed | cancelled` — and **derive**
  `started`/`completed` from `status` in `_rideToDomain` rather than carrying a separate boolean. This alone
  fixes D1, and makes D1 impossible to reintroduce.
- Keep an append-only **pending-actions list** on disk (`POST /rides/{id}/start`, `/complete`, `/cancel`),
  each with its own idempotency key (the repository already mints `ride_<epoch>_<6-digit>` keys for
  accept/cancel — extend the pattern to start/complete, closing D8).
- Apply a local transform per action to the in-memory ride, render that, and drain the queue on connectivity
  regain. On a fresh server snapshot, **re-apply the queued transforms** (E2's rebasing) so the UI never
  oscillates.
- Gate dependent actions on predecessors (no `/complete` before `/start` has synced), with a bounded wait
  that surfaces a real network error instead of pretending success.
- Keep-alive: a single `KeepAliveCount`-style gate in one file, incremented while phase ≠ terminal and while
  availability is online. On Android this requires `FOREGROUND_SERVICE` +
  `FOREGROUND_SERVICE_LOCATION` + `ACCESS_BACKGROUND_LOCATION` and a plugin such as
  `flutter_background_service`; on web there is no equivalent, so the web demo must be documented as
  foreground-only.

> Cost note from E5, worth inheriting: this structure demands strict conformance, and RIB-style scopes that
> outlive their Views leak. In Riverpod the equivalent hazard is keeping refs past disposal — `ref.onDispose`
> must clear every timer and socket, as the offers notifier already does for `_expiryTimers`.

### 5.2 Salted-hash code exchange  → upgrades G6, closes the plaintext-code weakness

Currently the rider's start code arrives as plaintext and is compared in the client, then re-sent to the
server. Adopt E3's pattern instead:

1. Server sends `{ start_code_hash, salt, algo: "sha256", max_attempts: 5, expires_at }` at assignment.
2. Client computes `sha256(salt + enteredCode)`, compares locally — instant feedback, works offline.
3. Client posts `{ ride_id, code_hash, attempt_seq, idempotency_key }`; **never** the plaintext.
4. Enforce `max_attempts` and `expires_at` client-side for UX *and* server-side for correctness; treat
   repeated failures as a fraud signal (E3 explicitly couples exhausted attempts to investigation and bans).

This is strictly better than both the current implementation and a naive "validate on server" fix: it works
in a dead zone, keeps the plaintext off the device, and gives the server a rate-limitable signal.

### 5.3 Push-first earnings with staleness fields  → closes D13, G8, G9

Adopt the `TrackerCard` envelope minimally, so the UI can never present an unlabelled stale number:

```
{ id, priority, isValid, expiresAt, lastUpdatedAt, outageState, payload: <typed> }
```

- Add `lastUpdatedAt`/`outageState` to `EarningsState` and render "آخر تحديث <time>" plus an explicit offline
  badge when the feed is cached. Today the screen shows whatever it last fetched with no age signal.
- Set `expiresAt` for time-scoped cards (daily summary) and **invalidate lazily on read** rather than by
  pushing expiry events — E4's reason holds for us at any scale.
- Drive it from the trip lifecycle we already have: a completed ride is the local event that should update
  the earnings card immediately (optimistically), with the server number reconciling it later. That removes
  the pull-on-read model in `earnings_view_model.dart:10`, which is also why `HomeState.earningsSummary`
  never gets a value.
- For the cash market specifically, the card set needs a second card our model already anticipates:
  **cash owed** (`cashCollected − platformCommission` rolled up), not just "earned". The domain fields exist;
  the projection does not.

---

## 6. What a decompile would have added — and why it is still the wrong trade

`[I]` If the APK had been unpacked, the plausible marginal yield was:

- Exact wire paths and payload schemas (REST/gRPC) beyond what the public contract states.
- The concrete RIB tree and scope boundaries at the current release.
- Bundled design assets and any hardcoded server-driven defaults.
- Analytics event names and their payloads.

Why it still loses:

1. **Legal exposure.** Anti-circumvention statutes plus ToS breach, in a product owned by the competitor
   being cloned. That risk lands on the operator, not on the analysis.
2. **Technical yield is poor.** R8/ProGuard renames types and members; protobuf/gRPC payloads are opaque
   without the `.proto`; obfuscated strings tell you little about a state machine. The genuinely valuable
   parts — optimistic mode, keep-alive, cash settlement — are architectural, and Uber described them in *more*
   usable detail than decompiled code would.
3. **Clean-room contamination.** Once proprietary implementation is internalised, "we designed this
   independently" stops being defensible. Everything in §5 is attributable to a public engineering article,
   which preserves that defence.
4. **The gap is already proven from our own side.** §4 shows the deficits by reading our manifests and
   repositories. We do not need Uber's bytecode to know we lack a persisted trip state machine — we need
   `activeRideId` to stop being a `String?` in RAM.

If deeper competitive fidelity is genuinely required later, the defensible route is a **personally observed
black-box study**: a driver account on a test device, screen-recorded against the public app, with reverse
engineering limited to observable behaviour and interface — the standard practice for interoperability
analysis, and one that yields UX flows rather than source.

---

## 7. Recommendations

**P0 — the three things that make the app unusable in the field** (all independently fatal)

1. Fix `D20`: declare `INTERNET` in `android/app/src/main/AndroidManifest.xml`. Until then nothing in §3 is
   reachable in a shipped build.
2. Fix `D21` + `D22`: declare location and foreground-service permissions and add the single keep-alive gate
   (§5.1). Without it, the driver app is a foreground-only demo.
3. Fix `D1`/`D2` via the persisted `RideSession` + phase derivation (§5.1). This is the smallest change with
   the largest behavioural effect, and it is testable without a network.

**P1 — the cash market differentiator**

4. Ship the salted-hash code exchange (§5.2): security, offline capability, and an abuse signal in one change.
5. Add the cash-owed card and arrears state machine (G7). Our `CompletedRide` already has the fields; the
   lifecycle and the "settle with the platform" surface are missing.
6. Rebuild earnings as a card feed with staleness fields (§5.3) and delete the dead `earningsSummary` /
   `fetchEarningsSummary()` pair.

**P2 — parity polish**

7. Persist availability so online state survives restart (G11).
8. Replace the stale `README-SETUP.md` (it documents `lib/core/map_provider.dart`, which does not exist) and
   rotate the committed demo map key (D23).
9. Wire the already-translated ARB catalogue (D16) if English is a requirement; the strings are done, only
   `l10n.yaml` + `generate: true` + `AppLocalizations` adoption are missing.

---

## 8. Uncertainties

- [ ] **Is Uber's current app still the RIBs/Optimistic-Mode architecture?** The series is 2018–2019 and E1's
      listing dates to 2026; the mechanisms may have been re-implemented since. The *problems* they solve are
      permanent, so the designs transfer even if the implementation does not.
- [ ] **Cash rides vs cash delivery.** E3 documents the delivery arrears flow; rides use a simpler netting
      model (driver keeps cash, fees offset from digital trips). Which of the two matches Mishwar's intended
      settlement is a product decision we have not made.
- [ ] **Where does the 4-digit exchange code live in our flow?** We already have a rider-supplied
      `start_code`; E3's model assumes the *merchant* is given the code. The mapping is sound but the
      ownership of the secret (rider vs platform) changes who can defraud whom.
- [ ] **Do we need device attestation?** The loudest Play reviews are about account flags and secondary-device
      lockout. If Mishwar ever adds multi-device or risk scoring, that layer matters; today we have none.
- [ ] **Android-only is assumed.** `driver_app` has no `ios/` directory; Uber ships CarPlay and Android Auto.
      Whether iOS is in scope changes the keep-alive design substantially (background modes vs foreground
      service).
