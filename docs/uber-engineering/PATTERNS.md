# Uber Engineering — Patterns Worth Stealing (and Patterns to Ignore)

This is the second half of the Uber reading pass. [`INDEX.md`](./INDEX.md) catalogues
what the blog contains; this file records what is actually transferable to
Mishwar Yemen, and — just as importantly — what is not.

Every claim about Uber is sourced from a specific post, linked in the section
heading. Claims about Mishwar were checked against the schema and code, and the
checks that mattered are cited by file. The two are kept visibly separate —
several of my initial recommendations turned out to be already implemented, and the
document records that rather than quietly deleting it.

> **Read this as design input, not as a roadmap.** Mishwar today is a single
> NestJS API, one PostgreSQL instance with PostGIS, and no Redis (ADR-0003).
> Most of Uber's stack exists because they run 250,000 messages/second across
> 1.5M concurrent connections. Copying the components without the load is how
> you get a distributed system with none of the benefits.

---

## Source posts read in depth

| Date | Post | Slug | Subsystem |
|---|---|---|---|
| 2016-02-11 | Engineering the Routing Engine | `engineering-routing-engine` | Routing |
| 2018-06-27 | H3: Uber's Hexagonal Hierarchical Spatial Index | `h3` | Geospatial |
| 2019-11-06 | Improving Pickups with Better Location Accuracy | `beacon-improving-pickups-with-better-location-accuracy` | Location |
| 2020-12-18 | Uber's Real-Time Push Platform | `real-time-push-platform` | Real-time |
| 2022-11-02 | DeepETA: How Uber Predicts Arrival Times Using Deep Learning | `deepeta-how-uber-predicts-arrival-times` | ETA |
| 2026-08-06 | Zero Sum by Design: 10 Years of Uber's Payments Platform | `ubers-payments-platform` | Money |
| 2026-09-17 | How Uber Protects Against Retry Storms | `protecting-against-retry-storms` | Resilience |

Sections below are ordered by subsystem, not by date.

Archive-era posts not yet readable by pagination are listed in
[`INDEX.md` § Recovered legacy slugs](./INDEX.md#recovered-legacy-slugs).

---

## 1. Geospatial bucketing — H3

**Source:** [H3: Uber's Hexagonal Hierarchical Spatial Index](https://www.uber.com/blog/h3/), 2018-06-27

### What Uber did

They replaced ad-hoc geographic zones with a global discrete grid because every
marketplace question ("is supply short here?", "are these two requests close
enough to pool?") needs a *bucket* to aggregate into. Their evaluation:

- **Exact coordinates are too fine to aggregate; neighbourhoods are too coarse to be
  consistent.** Bucketing is the compromise.
- **They rejected postal-code polygons and hand-drawn operations zones.** Postal
  codes have "unusual shapes and sizes which are not helpful for analysis, and are
  subject to change for reasons entirely unrelated to what we would use them for."
  Ops-drawn zones "require frequent updating as cities change and often define the
  edges of areas arbitrarily."
- **Hexagons beat squares and triangles** for one reason: "hexagons have only one
  distance between a hexagon centerpoint and its neighbors', compared to two
  distances for squares or three distances for triangles." With squares you need
  two sets of coefficients (edge-neighbours vs vertex-neighbours) for any smoothing
  or gradient operation.
- **Projection:** gnomonic projections centred on icosahedron faces. 122 base cells
  (ten per face), plus twelve pentagons at the icosahedron vertices — unavoidable,
  because "it is not possible to tile the icosahedron with only hexagons." The
  Fuller orientation puts those pentagons in the ocean.
- **Hierarchy:** 16 resolutions, each one-seventh the area of its parent.
  "Hexagons cannot be perfectly subdivided into seven hexagons, so the finer cells
  are only approximately contained within a parent cell." Truncating a cell ID gives
  its ancestor, which is what makes roll-ups cheap — but truncation introduces a
  fixed shape distortion, while indexing at a resolution is exact.
- **API shape:** `geoToH3(lat, lng, res)` → 64-bit index; `h3ToGeo` and
  `h3ToGeoBoundary` invert it; `kRing(index, k)` returns cells within grid distance
  k, which "approximat[es] circles using the grid system."

Surge pricing is computed "by measuring supply and demand in hexagons in each city."

### What Mishwar should take

1. **The bucketing principle, not the library.** Any supply/demand or heat-map
   feature needs a stable cell that survives city-boundary edits. A
   `geography(Polygon)` service area is the right primitive for *"may I operate
   here"*; it is the wrong primitive for *"how many drivers are in this
   neighbourhood"* — because the answer changes when an admin redraws the boundary.

2. **If bucketing is needed, use one of two cheap paths first:**
   - `ST_SnapToGrid` over a fixed metre grid, or
   - a H3 column computed in application code and stored alongside the point.

   The second is strictly better for the *reporting* use case (stable IDs across
   boundary edits, one join key) and costs one indexed `bigint` column. There is a
   maintained `h3` PostgreSQL extension; evaluate it before writing cell math by
   hand.

3. **Do not add a cell column speculatively.** There is no surge, no pooling and no
   heat-map in v1. Land it with the first feature that needs it, as a migration
   plus a backfill — the column is derivable from `driver_locations` at any time.

### What Mishwar should NOT take

- The icosahedron. It solves a *global* equal-area problem. Mishwar operates a
  handful of Yemeni cities; `ST_Covers` against hand-drawn service areas is more
  accurate at that scale, not less.
- Multi-resolution roll-ups. Yemen's cities at H3 resolution 7–8 are small enough
  that one resolution covers essentially every aggregate Mishwar will ever need.

### Contradiction worth knowing

H3's whole argument is that ops-drawn zones are arbitrary and unstable. Mishwar's
[`docs/architecture.md` § 5](../architecture.md) deliberately uses ops-drawn
`service_areas` polygons. **Both are correct at their respective scales.** Uber
needs a grid because it must compare Lagos to São Paulo to Jakarta with one
formula. Mishwar needs polygons because a service area in Sana'a is a legal and
operational statement ("we do not go there"), not an analytical convenience. The
distinction: polygons gate *eligibility*, grids aggregate *statistics*. Never use
one for the other's job.

---

## 2. Driver location accuracy — beacon

**Source:** [Improving Pickups with Better Location Accuracy](https://www.uber.com/blog/beacon-improving-pickups-with-better-location-accuracy/), 2019-11-06

### What Uber did

They shipped **hardware**. A dashboard-mounted unit with GNSS + accelerometer +
gyroscope + barometer, fused into a single location estimate, because:

- Phone GNSS quality varies enormously across the driver fleet.
- "Even the best receivers perform poorly in downtown areas and other urban
  canyons because of GNSS RF signal reflections from buildings, or in tunnels and
  stacked roads where GNSS coverage may be absent."
- Sensor coverage on phones is uneven: "almost 95 percent of smartphones used by
  Uber driver-partners in the US feature a gyroscope, but only about 60 percent
  have a barometer."
- The beacon is rigidly mounted, so its pose is stable in a way a handset on a
  dashboard mount is not.

The fusion technique that matters most is **dead reckoning**: accelerometer and
gyroscope readings integrate position and heading *between* GNSS fixes, so the
location does not freeze or teleport when satellites drop out. Concretely:

- "Beacon uses this accelerometer measurement for dead reckoning between GPS points
  and to smooth sudden location jumps… Sudden location jumps that require
  acceleration much higher than that observed by the accelerometer are filtered."
- Heading gets the same treatment: "Sudden heading changes in GNSS measurement that
  are not consistent with gyroscope measurement are filtered."
- Motion constraints are imposed as physical priors: "During regular vehicle
  motion, it is reasonable to assume that the vehicle does not slide sideways or
  jump upwards."
- Barometer: ~1 Pa RMS noise ≈ **8 cm** altitude resolution — and altitude is what
  distinguishes stacked roads and tunnels.

The failure modes they document are the ones Mishwar will hit on day one:

- **Tunnels:** "If raw GNSS location is used for vehicle positioning inside a
  tunnel, it will stay stuck at the start of the tunnel till the driver exits."
- **Urban canyons:** "in some cases, the GNSS location can have errors of more than
  100 meters… causing the location to be on the wrong side of the street."

### What Mishwar should take

1. **The `(lat, lng, accuracy_m, recorded_at, received_at)` tuple already exists —
   use it.** `driver_location_updates` stores all five, which means the beacon lesson
   is already structurally satisfied. What is missing is that **ranking ignores it**:
   `dispatch.service.ts` orders purely by `ST_Distance` over
   `driver_profiles.last_location`, and `driver_profiles` carries no accuracy figure
   at all. The data needed to distrust a bad fix is written on every update and then
   discarded at read time.

2. **Reject the teleport in the dispatcher, not in the UI.** Two consecutive fixes
   implying a speed above a threshold (say 200 km/h between timestamps) mean the
   newer fix is junk *for ranking purposes*. Uber filters these with an
   accelerometer; Mishwar has no accelerometer, so the timestamp delta is the only
   available physics check — and it is sufficient at Mishwar's scale.
   `driver_location_updates` already captures `speed_mps`, so the check can be made
   without inferring anything.

3. **Never render an unfiltered fix as "live".** `docs/architecture.md` § 6 already
   mandates this ("بعد تجاوز العتبة يظهر «آخر موقع معروف منذ …» لا «مباشر»").
   beacon's contribution is the *reason*: raw GNSS in a bad environment is
   confidently wrong, not obviously wrong.

### What Mishwar should NOT take

- Hardware. That is a supply-chain and logistics decision, not an engineering one.
- Dead reckoning / Kalman fusion on the server. It needs high-frequency IMU samples
  that only an on-device SDK can produce, and it is solving a metre-level problem
  when Mishwar's first problem is a *hundreds of metres* problem: riders and
  drivers cannot find each other because there are no reliable street addresses.

### The pickup problem Mishwar actually has

Uber's beacon exists to answer "where is the car, to within a metre." In Yemen the
unanswered question is "where is the *door*." The high-leverage analogue is not
sensor fusion, it is a **saved pickup point**: let the rider drop a pin once
(a gate, a named landmark, a building entrance), store it as a `geography(Point)`
with a free-text label, reuse it on the next request, and show the driver the label
alongside the coordinate. That is a schema and UX change, not a signal-processing
change — and it addresses the failure mode that actually causes cancelled trips.

---

## 3. Real-time delivery — RAMEN

**Source:** [Uber's Real-Time Push Platform](https://www.uber.com/blog/real-time-push-platform/), 2020-12-18

### What Uber did

They started with polling and hit a wall: "at some point, 80% of requests made to
the backend API gateway were polling calls." The symptoms they enumerate are a
checklist of what Mishwar will experience if it over-polls:

- battery drain, app sluggishness, network congestion;
- "especially evident in places with 2G/3G networks or spotty networks across the
  city where the app retries multiple times for each polling attempt";
- dozens of overlapping polling APIs, each carrying several features;
- **cold start is the worst case** — "every time the app was opened, all the
  features wanted to pull the latest state… the app could not render until critical
  components were retrieved from the server."

Their replacement, RAMEN, separates three concerns that are easy to conflate:

| Concern | Component | Question answered |
|---|---|---|
| Triggering | **Fireball** | *When* should a message exist? |
| Payload | **API gateway** push middleware | *What* is in it? |
| Delivery | **Streamgate** + Helix/ZooKeeper | *How* does it reach the device? |

Two design decisions in that separation are directly reusable:

1. **Push APIs share business logic with pull APIs.** "A given payload can be
   seamlessly switched from a pull API to a push API… the same logic is used
   whether your app is pulling a 'user' object via a pull API call or Fireball is
   sending a 'user' object via a push API call." The gateway grows a "Push"
   middleware that intercepts a pull API's response and forwards it to delivery.
   **This is why Mishwar's `GET /v1/rides/active` and its WebSocket event must be
   built from the same serializer.**

2. **Every message carries policy metadata.** Three priority buckets (High =
   core experience, Medium = incremental, Low = large/rare), a **TTL** ("a few
   seconds to up to 30 minutes… the delivery system will persist the message and
   retry delivery until the time to live value expires"), and a **dedupe** flag
   ("for the majority of our use cases, sending the most recent push message of a
   given type was enough").

3. **Delivery is at-least-once, and the protocol is built around that.** SSE gave
   them a unidirectional stream, so they layered sequence numbers on top:
   the client opens `/ramen/receive?seq=0`, the server sends pending messages in
   descending priority with incremental sequence numbers, and on reconnect the
   client presents the highest sequence number it actually saw. "That tells the
   server that even though number 3 was written to the socket, it never got
   delivered." Liveness is a **1-byte heartbeat every 4 seconds**; the client
   declares the connection dead after 7 seconds of silence; an explicit
   `/ramen/ack?seq=N` is sent every 30 seconds regardless of link quality.

4. **They outgrew their first topology and said so.** The Node.js + Ringpop
   version was sharded by user UUID with Redis for persistence. It worked until
   gossip convergence time grew with ring size, and "Node.js workers were single
   threaded and would have elevated levels of event loop lag resulting in a further
   delay in the convergence of membership information" — which caused message loss.
   They moved to Netty + ZooKeeper + Helix with Cassandra for cross-region
   durability and Redis purely as a **capacity cache to prevent thundering herd on
   deploy/failover**.

Scale markers, for calibration: 70,000 QPS / 600,000 connections on the first
generation; 250,000 messages/second / 1.5M connections / 99.99% server-side
reliability on the second.

### What Mishwar should take

> **Context correction:** `docs/architecture.md` § 6 *specifies* the realtime contract
> (`ride_id` + `ride_version`, `GET /v1/rides/active` on reconnect), but there is no
> WebSocket gateway in `apps/api/src/modules` — the layer is designed and unbuilt. So
> these are requirements for the module, not fixes to it.

1. **Adopt the sequence-number + version contract now, while it is free.**
   `architecture.md` § 6 already specifies it. That is the same insight RAMEN arrived
   at, minus the wire-protocol tax. The reason to honour it rather than simplify it:
   a payload without a version field cannot be fixed without re-shipping every
   installed app.

2. **Give every pushed event a TTL, and reuse the dedupe key you already have.**
   `notifications` already carries `dedupe_key` with a unique partial index, so
   deduplication is solved. Staleness is not: `notifications` has no `expires_at`, and
   an `offer` message that arrives 90 seconds late is worse than no message — it makes
   a driver act on a dead offer.

3. **Build events from the same serializer as the REST read.** If
   `GET /v1/rides/:id` and the WebSocket `ride.updated` payload drift, clients
   silently disagree about state. One function, two transports. This is cheapest to
   establish in the first commit of the gateway, before there are two code paths.

4. **Heartbeat + explicit death threshold.** A WebSocket that is half-open looks
   alive to the client. Ping on a fixed interval; declare dead after 2–3 missed
   intervals; reconnect and re-fetch. This matters more in Yemen than in San
   Francisco — half-open TCP on mobile networks is common.

### What Mishwar should NOT take

- Helix, ZooKeeper, Cassandra, Streamgate, Fireball. All of it exists to hold
  millions of sockets across regions. A single NestJS process with `ws` handles
  Mishwar's entire foreseeable concurrency.
- SSE-over-HTTP as a bespoke resumable protocol. NestJS's WebSocket gateway plus a
  version field gets 90% of the benefit at 5% of the complexity.

### The one place Mishwar should copy the *architecture*, not just the idea

RAMEN's separation of **triggering** (when), **payload** (what) and **delivery**
(how) is worth preserving structurally even inside one process. Mishwar's
`Notifications` module should decide *whether* an event is worth sending; the
domain should own *what* the event contains; the gateway should own *how* it
travels. The failure mode this prevents is domain code that calls
`ws.send(...)` directly, which welds business rules to a transport and makes the
push/pull-logic-sharing property impossible.

---

## 4. ETA — DeepETA

**Source:** [DeepETA: How Uber Predicts Arrival Times Using Deep Learning](https://www.uber.com/blog/deepeta-how-uber-predicts-arrival-times/), 2022-11-02

### What Uber did

DeepETA is a **post-processing residual model**, not a router. Three hard
constraints framed the whole design:

- **Latency:** "The model must return an ETA within a few milliseconds at most."
- **Accuracy:** MAE must beat the incumbent XGBoost model.
- **Generality:** one model for "all of Uber's lines of business such as mobility
  and delivery" across the globe.

Why the latency constraint is that tight: "This post-processing model is the
highest QPS (queries per second) model at Uber."

Findings that transfer as *reasoning*, independent of the model:

1. **Bucketize continuous features before embedding them.** "Somewhat
   counterintuitively, bucketizing continuous features led to better accuracy than
   using continuous features directly." The mechanism: "a network with bucketized
   features may have an advantage because it doesn't have to spend any of its
   parameter budget learning to partition the input space."
2. **Quantile buckets beat equal-width buckets** because they "maximize entropy:
   for any fixed number of buckets, quantile buckets convey the most information
   (in bits) about the original feature value."
3. **Geo features need multi-resolution treatment with hashing.** They compared
   exact indexing (most space), feature hashing (less space, "the accuracy was the
   same or slightly worse… likely due to hash collisions"), and **multiple feature
   hashing** with independent hash functions — which won, because "the network is
   able to combine the information from multiple independent hash buckets to undo
   the negative effects of single-bucket collisions."
4. **Linear transformer for the speed.** Original self-attention is O(K²d),
   linear is O(Kd²); with K=40 features and d=8 dimensions that is 12,800 vs 2,560.
   "It's clear that the linear transformer is faster whenever K>d."
5. **Sparsity is the real speed trick.** "While the model has hundreds of millions
   of parameters, any one prediction touches only a tiny fraction of them, roughly
   0.25%." A shallow net with parameters in embedding tables turns inference into
   "O(1) hash lookup", versus O(log N) for a tree or O(N²) for fully-connected
   layers. They name it explicitly: "discretizing and embedding inputs is simply an
   instance of the classic space vs time tradeoff."
6. **Different consumers need different point estimates.** "We want to estimate a
   mean ETA for fare computation but need to control for the effect of outliers.
   Other use cases may call for a specific quantile." Hence **asymmetric Huber
   loss**, "robust to outliers and can support a range of commonly used point
   estimates."
7. **Serving path:** consumer → **uRoute** (frontend for all routing lookups) →
   routing engine (route-lines + ETA) → **Michelangelo Online** prediction service.
   Periodic auto-retraining workflows validate the model.

### What Mishwar should take

1. **The layered-ETA contract, which is the single most useful idea here.**
   Uber separates *routing-engine ETA* (physics: distance ÷ speed) from *model ETA*
   (correction: historical residuals for this origin, destination, hour). Mishwar
   should mirror that split from the start even with no model:
   - routing adapter → raw ETA
   - a `eta_adjustment` seam → currently identity, later a learned offset
   This is exactly what Uber called **Goldeta** in 2014: "a model that sat on top of
   the routing engines and made an adjustment to those original estimates using our
   own historical Uber Data." Their documented weakness was the **cold start**:
   "when we launch in new cities we didn't have enough data to inform an ETA
   offset." *Mishwar is permanently in that cold-start regime for its first cities.*
   Design for the identity case to be correct, not embarrassing.

2. **Store the prediction and the outcome, always.** You cannot compute a residual
   model without historical `(features → predicted → actual)`. Mishwar already has
   the state machine; what it needs is a durable record of `quoted_eta_seconds` at
   assignment and `actual_arrival_at` at arrival. One table, written from the same
   place that owns `rides.status` (`Trips`, per
   [`architecture.md` § 3](../architecture.md)). Collect the data before you have a
   model — the alternative is discovering in year two that you have no history.

3. **Never present a straight-line estimate as a duration.** `architecture.md` § 5
   step 4 already mandates this: order by distance "كتقدير فقط" and label numbers
   "تقديرية" until a routing provider is configured. DeepETA is the elaborate
   version of the same discipline — Uber had a routing engine and *still* treated
   its output as an input to be corrected, not as truth.

4. **Quantile/percentile thinking for commitments.** If Mishwar ever shows "driver
   arrives in 4 minutes" as a promise, that is a *quantile*, not a mean — the mean
   makes half your riders late. Uber's asymmetric loss is the machinery; the
   product decision (which quantile to quote) is the part that matters and costs
   nothing to make now.

### What Mishwar should NOT take

- **DeepLearning anything, including DeepETA itself.** A transformer with hundreds
  of millions of parameters requires Michelangelo, a feature store, GPU training
  and an online prediction service. The ratio of infrastructure to benefit at
  Mishwar's volume is roughly infinite.
- Multi-resolution geo hashing. It exists to fit *planetary* resolution into a
  fixed embedding budget. Mishwar has a few cities.
- Reading DeepETA as "we need ML for ETA." The transferable claim is narrower and
  more useful: **routing gives you physics, residuals give you local truth, and the
  residual term needs history you must start recording today.**

---

## 5. Routing — Gurafu

**Source:** [Engineering the Routing Engine](https://www.uber.com/blog/engineering-routing-engine/), 2016-02-11

### What Uber did

The ETA is "the first thing a rider sees when opening the app." Early stack was
OSRM plus **Goldeta**, a residual model over historical trips. Two problems ended
that era: cold start in new cities, and "the development was slowed by having to
implement it to an open source solution (OSRM) which wasn't built from the ground
up with a dispatching system in mind."

The primer they give is the clearest short statement of routing-graph design in the
corpus:

- The road network is a graph: "Nodes represent intersections, and edges represent
  road segments. The edge weights represent a metric of interest: often either the
  road segment distance or the time take it takes to travel through it."
- Real-world constraints live in the graph: "one-way streets, turn restrictions,
  turn costs, and speed limits are modeled in the graph as well."
- There are two representations with a genuine trade-off: node-based, or
  **edge-based** where "road segments [are] nodes, and edges [are] the transition
  between one road segment to another. Each representation has its own tradeoffs,
  so it's important to know what you need before committing."

Then the decisive number, and the reason any of this matters to Mishwar:

> "Below 100 milliseconds in the 99th percentile response time. We need this because
> **this calculation is done every time before a vehicle is dispatched to a ride
> request.**"

**Routing sits inside the dispatch loop.** That single sentence explains Uber's
entire routing architecture: the latency budget is not a UX nicety, it is a
throughput constraint on the matching system.

They then documented three approaches and why each failed — this is the most
valuable part of the post:

| Attempt | Why it failed |
|---|---|
| **Dynamic contraction hierarchies** | Full preprocessing is ~12 h for the world graph. Dynamic updates cut that to 10 min "even with 10% of the road segments changing traffic speed. However, 10 minutes is still too much of a delay… this path was ultimately a dead end." |
| **Sharding by region** | "would introduce bottlenecks in the cluster size of servers for each region. If one region received too many requests during peak hours, the other servers couldn't share the load… we did not implement this solution" |
| **A\*** | No preprocessing, good for short en-route trips, but "the A* response grows geometrically in relation to the depth of nodes traversed" — Presidio → Mission District was **~120 ms**, "several times longer than contraction hierarchies." Even A* with landmarks was not viable. |

The shipped answer: re-run preprocessing **only for a small part of the graph**,
by dividing it into "layers of small cells which are relatively independent of each
other," preprocessed **in parallel**. Launched globally April 2015 with **Flux**,
"Uber's first historical traffic system based on GPS data we collect from partner
phones."

Measurement discipline, which is easy to skip and shouldn't be: they built a tool
to "ingest our Kafka logs in real time to retrieve the actual time of arrival (ATA),
and compare that to our ETA," plus "a rich set of web tools to visualize, inspect
and compare routes from different models and providers" — because "measuring route
quality sometimes requires visual inspection on a case-by-case basis."

Target: "hundreds of thousands of ETA requests per second, with single-digit
milliseconds response time."

### What Mishwar should take

1. **The dispatch-loop insight, and its cost ceiling.** If routing is called once
   per dispatch evaluation, then routing latency multiplies by (candidates ×
   batches). Mishwar's dispatcher ranks candidates by straight-line distance for
   exactly this reason. When a routing adapter does land, the correct integration
   is to call it **for the shortlist only** (the batch you are about to offer), and
   to cache aggressively — never to call it inside the candidate-scan loop.

2. **Model the road network's constraints before you need routing.** Turn
   restrictions, one-ways and turn costs are the reason "distance ÷ speed" is wrong
   even for a rough ETA. When Mishwar evaluates routing providers, the evaluation
   criterion is not "does it return a duration" but "does it model one-ways and turn
   restrictions." In dense old-city street patterns this is the difference between
   a plausible number and a fiction.

3. **Design the adapter seam for the two-layer ETA now** (see § 4). The routing
   adapter returns `{distance_m, duration_s, route_geometry}`; the ETA the rider
   sees is that duration plus an adjustment term that starts at zero.

4. **Instrument `(quoted, actual)` from day one.** Uber compares ETA to ATA via
   real-time log ingestion. Mishwar does not need streaming; it needs two columns
   and a nightly query. Without them you cannot answer "is our ETA getting better or
   worse?" — and without that answer, no ETA work is justifiable.

5. **Copy the failure documentation habit.** Uber's post is valuable *because it
   lists three dead ends with the numbers that killed them* (10 min, region
   bottlenecks, 120 ms). Mishwar's ADRs should record rejected alternatives the same
   way; several already do (ADR-0003 records why Redis was deferred).

### What Mishwar should NOT take

- Contraction hierarchies, cell layering, or writing a routing engine. Years of
  specialist work for a problem a hosted routing provider solves at Mishwar's
  volume.
- Flux-style historical traffic from driver phones. It is a genuinely good idea
  (Mishwar's drivers *are* the sensor fleet) but it requires enough trips on enough
  segments to be statistically meaningful. Revisit it when there is trip volume and
  a reason to distrust the provider's traffic — not before.

---

## 6. Money movement — the payments ledger

**Source:** [Zero Sum by Design: 10 Years of Uber's Payments Platform](https://www.uber.com/blog/ubers-payments-platform/), 2026-08-06

### What Uber did

Gulfstream began in 2016 with "a small team [bootstrapping] a foundational set of
microservices." Ten years later, "many of those services still run in production,
reflecting the durability of the system's early design" — while gross bookings went
from $50B to $217B and the platform grew to "ledger balances for more than 1.2
billion entities."

Four principles, stated by the authors as the reason no re-architecture was ever
needed:

1. **Immutable money orders.** A money order "is a series of debits and credits
   between the entities involved in the real-world commerce transaction (such as a
   trip, an Uber Eats order, a freight shipment, or a digital Uber Cash top-up)."
   "To make our system self-auditable, we made our money order immutable." The
   adjustment case is answered directly: "What happens when a trip is adjusted or a
   food item is missed…? We write additional money orders to capture the adjustment.
   But the principle stands; an order once written can't be changed in any shape or
   form."

2. **Zero sum, enforced pre-commit.** "Before writing a money order down, we always
   run pre-commit validations. One of the validations is to ensure that all entries
   in any money order sum to zero. That is, no money can ever be created or
   destroyed." Backed by double-entry bookkeeping: "every credit entry on the order
   has an equivalent debit entry."

3. **Strongly consistent balances.** No off-the-shelf store gave them the guarantee,
   so they built it: each entity's sub-ledger accounts live "as a single row in
   DynamoDB", typically 1KB — and they had to "ensure any sub-ledger account with a
   0 balance was pruned to manage the row size."

4. **Three data models, chosen early and never replaced:**
   - **Money order** — money movement between two or more entities.
   - **Ledger** — a real-world entity with one or more accounts, each holding a
     balance.
   - **Entity changelog** — "captures balance updates on the ledger, providing a
     complete audit trail and the ability to recreate an entity's ledger since
     inception."

Two generalisations did the long-term work. **LOB-agnostic money orders**
(collection, disbursement, refund) meant "Uber Freight, 2-wheels, Transit, Hotels,
Rental Cars, Grocery & Retail, Ads, Memberships… needed very little to no changes
within the core platform." **Instrument-agnostic payments** — a generic interface
with `charge`, `disburse`, `refund` — meant 50+ payment methods could plug in
"with little to no change to the core platform."

Their hardest-earned lesson is **Entity Fares**. They could model any number of
parties, but "our upstream systems didn't fully have the same flexibility nor
enforce the same principles (like zero-sum). Any ambiguity in fare representation
directly conflicted with the core principles we had established." The fix: "explicitly
recording fares for every participating entity and enforcing the zero-sum principle
**at the point of computation**."

And the **hot entity problem**: B2B growth meant hammering the same ledger row, so
"maintaining strong global consistency while frequently updating the same ledger row
posed a significant hurdle to serialized write performance." Solved with "a
specialized, serialized batch-write mechanism", for 10x throughput on those rows.

### Mishwar already implements most of it — verified, not assumed

Read alongside [`docs/adr/0005-money-representation.md`](../adr/0005-money-representation.md)
and [`docs/architecture.md` § 3–4](../architecture.md).

This is the most important finding in this file. Checked against the actual
migrations and domain code, Mishwar has independently landed every one of the
principles below. Anyone proposing to change these should be told they are undoing
something deliberate:

| Uber principle | Mishwar implementation | Where |
|---|---|---|
| Immutable money orders | Append-only, enforced by a DB trigger; corrections are `REVERSAL` rows linked via `reverses_entry_id`; `quoted_total` never rewritten, adjustments land in `final_total` | `0001_init_schema.sql`, `0002_integrity_guards.sql`, `architecture.md` § 4 |
| Zero-sum at point of computation | `commission_amount + driver_net = final_total` as a table `CHECK`; `AMOUNTS_DO_NOT_BALANCE` thrown by the pure builder before any insert | `rides` constraint; `domain/ledger.ts:65` |
| Balance as a projection, not a column | `driver_balances` is a **`VIEW`** over `SUM(amount)` — inherently rebuildable, so the "entity changelog" property is satisfied for free | `0001_init_schema.sql:500` |
| Cash as an explicit movement | `CASH_COLLECTED` entry type: `EARNING +N` and `CASH_COLLECTED -F` net to `-C`, i.e. the driver owes the commission | `domain/ledger.ts:9–12, 61–82` |
| Instrument-agnostic | Every external service behind an Adapter; electronic payment is "واجهة Adapter فقط" in v1 | `architecture.md` § 2.5, § 7 |
| Unique idempotency key per movement | `idempotency_key text NOT NULL UNIQUE`, deterministically derived (`ride:<id>:EARNING`) so a replay cannot double-post | `0001_init_schema.sql`; `ledger.test.ts:11` |

The `CASH_COLLECTED` design in particular is *better than what this document was
originally going to recommend.* Modelling cash as "the driver physically holds F
that belongs to the platform flow" and letting the balance net to `-C` is exactly
the honest representation of a cash-first marketplace, and it was already there.

### The one real gap: the ledger is single-entry

Uber validates that "all entries in any money order sum to zero", backed by
double-entry bookkeeping where "every credit entry on the order has an equivalent
debit entry." Mishwar's ledger is **signed-driver-balance only**: a cash trip posts
`+N` and `-F`, summing to `-C`, not zero. That is internally correct for a driver
wallet, but it has a specific consequence worth stating out loud:

> **Platform commission revenue exists nowhere in the ledger.** The only record of
> it is `rides.commission_amount` and the `price_breakdown` snapshot — a different
> source of truth that can drift from the ledger with nothing to detect it.

Two acceptable resolutions. Pick one and write it down; do not leave it ambiguous:

- **(a) Accept single-entry, and declare `rides.commission_amount` the sole revenue
  source of truth.** Cheapest. Requires an explicit prohibition: revenue is never
  derived by summing ledger entries, because the ledger does not contain it. A
  comment on `driver_balances` and a line in ADR-0005 is enough.
- **(b) Add a platform counterparty** so each money order sums to zero, which is
  what Uber means by zero-sum. Correct, but it is a schema change across every
  entry type and it is much easier now than after production data exists.

Option (a) is the right call for v1, but only if it is *decided* rather than
stumbled into. The failure mode is a future reconciliation report that sums the
ledger, gets a different number from the rides table, and nobody knows which is
right.

### Two smaller deltas

- **The `driver_balances` view will eventually need a floor.** It is a full
   `GROUP BY` over every entry for a driver, recomputed on each read. That is
   correct and free at current volume; at tens of thousands of entries per driver it
   becomes a slow `GET /v1/wallet`. The Uber-compatible answer is not a mutable
   balance column (that reintroduces the hot-entity problem they had to engineer
   around) but a periodic snapshot row plus a delta query, or a materialised view.
   Note it, do not build it.

- **Mishwar sidesteps Uber's hot-entity problem entirely, and should know it.**
   Uber needed "a specialized, serialized batch-write mechanism" for 10x throughput
   because B2B customers hammered one ledger row. Mishwar's design has no ledger row
   to hammer — `driver_ledger_entries` is insert-only and the balance is derived. That
   is a structural advantage of the append-only choice, worth recording as such.

- **Prune settled drivers, not accounts.** Uber prunes zero-balance sub-accounts "to
   manage the row size" because every sub-account is a field in one 1KB row. Mishwar
   has no per-account rows, so there is nothing to prune — a clean illustration that
   most of the operational machinery in this post is downstream of one storage
   decision Mishwar did not make.

### What Mishwar should NOT take

- DynamoDB, LedgerStore, Kafka, Cadence. Every one of those exists for reasons
  (1.2B entities, tamper-evident audit, cross-service async, synchronous-in-async
  flows) that are a decade away. PostgreSQL with a transaction and a unique
  constraint on `(ride_id, entry_type)` gets Mishwar a very long way — and already
  has, per the table above.
- Ledger-as-a-Service / multi-tenancy. There is exactly one tenant.
- The hot-entity batch-write machinery, for the reason above.

---

## 7. Failure amplification — retry storms

**Source:** [How Uber Protects Against Retry Storms](https://www.uber.com/blog/protecting-against-retry-storms/), 2026-09-17

### What Uber did

They formalised why retries are dangerous, with the arithmetic.

In a straight call chain of depth ɗ where every hop retries once, the load on the
node at depth ɗ is:

```
R^ɗ × Ƞ        (R = retries per hop)
```

A seven-node chain with one retry each puts **8×** traffic on the deepest node. With
a retry *budget* B, it becomes `(1+B)^ɗ` — a 10% budget gives 1.33× at depth 6
instead of 8×. Better, but still multiplicative.

The insight that actually fixes it is that **retries are only useful if the error is
independent and retryable** — and during overload they are neither:

> "in many real-world scenarios like service overload, bad database hosts, database
> overload, or sharding issues, the probability of retries remains high even with
> retries… during periods of high error rates from a service, the errors are less
> likely to be randomized, and wouldn't benefit from a higher number of retries, and
> instead might be responsible for further degradation."

Hence **error ownership**:

> "If a service calls N outbounds for fulfilling a request, and if an outbound
> error-out causes it to return an error, then the error returned by that service is
> only a **symptom**. Simultaneously, in the context of the service, the **cause** is
> the incoming error from its downstream. However, if no outbound of the service
> errors out while fulfilling the request and it still returns an error, the service
> is the **cause** of the returned error, and is the owner."

Mechanically: an `x-uber-error-claim` header travels with the response. A service
that merely propagates a downstream failure **unclaims** the error, which tells its
caller not to retry. "Here, the first node to see a missing error claim from a
downstream unclaims the error, limiting the impact radius of the retry disturbance
(it's no longer a storm)." Their production numbers: max retry-storm radius across
all user-facing APIs fell from **25 to 3**, average from **20 to 2**; during an
18 November 2025 outage rooted five levels deep, they "stopped a staggering 9.5
million spurious requests."

### What Mishwar should take

1. **The one rule that matters: exactly one retry layer per logical operation.**
   `architecture.md` § 6 puts retries on the client (backoff, same
   `Idempotency-Key`) — that is the correct choice, because the client is the only
   party that knows whether the user still cares. The corollary Uber's post makes
   explicit is that **the server must then not also retry that operation**. Mishwar's
   adapters (SMS/OTP, FCM, maps, payment) are the deep chain; an adapter that retries
   internally, inside a request the client is already retrying, is `R²` for free.

2. **Do not retry 4xx. Ever.** Retry on connection failure and 5xx only. An
   idempotency key makes a retry *safe*; it does not make a retry *useful*.

3. **Count your hops.** Mishwar's deepest path is roughly client → API → adapter →
   provider. That is depth 3. At depth 3 with one retry per hop you get 8×; the
   arithmetic only becomes catastrophic when chains get long, which is the strongest
   argument for keeping the architecture as shallow as it is.

4. **Model the "provider is down" case as a product state, not an exception.**
   Mishwar's `architecture.md` § 2.5 already forbids silent degradation: "لا تعمل أي
   خدمة غير مهيأة بصمت: تفشل بوضوح أو تستخدم محوّلًا للتطوير يرفض الإقلاع في
   الإنتاج." Extend the same honesty to runtime: if the SMS provider is down, OTP
   login should return a clear failure, not retry until the request exceeds its
   timeout and the client retries too.

5. **Bounded concurrency at the adapters.** Even with correct retry logic, an
   adapter called from a sweeper that processes every overdue ride can emit N
   near-simultaneous calls. Cap concurrency per external provider; the sweeper
   (ADR-0003) is exactly the component where this is easy to get wrong.

### What Mishwar should NOT take

- Error-claim propagation across a service mesh. Mishwar has no mesh and, at three
  hops, no amplification problem worth instrumenting. The header scheme exists
  because Uber's call chains reach depth 25.
- Service Dependency Analysis. Same reason.

---

## 8. Cross-cutting principles Uber states explicitly

These appeared repeatedly and are cheap to adopt.

- **Separate "when", "what" and "how".** RAMEN's Fireball/gateway/Streamgate split,
  and the fact that they "could support gRPC on exactly the same architecture but
  with different wire protocols," is a general lesson: if the transport is swappable
  without touching business logic, the seams are in the right place.
- **Reuse one payload builder for pull and push.** Otherwise the two transports
  drift and clients see contradictory state.
- **Put policy on the message, not in the sender.** Priority, TTL and dedupe are
  per-message metadata, so the delivery layer can make decisions without knowing
  about rides, offers or fares.
- **Measure against the incumbent, with the metric named in advance.** DeepETA's
  constraints were written as MAE-improvement and latency-ceiling before the work
  started. Routing's ETA-vs-ATA comparison is the same discipline.
- **Document the dead ends with their numbers.** All three Gurafu failures are
  stated with the measurement that killed them.
- **Prefer a stable, boring bucket over a precise, unstable one.** H3's rejection of
  postal codes; the layered structure of RAMEN's topology. Stability of the
  identifier is worth more than fidelity of the boundary.

---

## 9. Scale mismatch: the explicit do-not-copy list

Uber publishes at a scale where the constraints are entirely different. Anything in
this list requires an organisational reason, not a technical one, before it belongs
in Mishwar:

| Uber component | Why it exists there | Mishwar substitute |
|---|---|---|
| H3 global grid | Comparing cities across the planet with one formula | `service_areas` polygons + optional snapped grid for stats |
| Gurafu routing engine | Routing runs before every dispatch decision; 100k+ QPS | Hosted routing provider behind an adapter |
| Contracted graphs / cell layering | Real-time traffic at world scale | Provider traffic data; revisit with trip volume |
| Flux historical traffic | Millions of partner phones as a sensor fleet | Provider data, then trip-derived estimates |
| beacon hardware | Sub-metre pickup accuracy | Saved pickup points + accuracy-aware UX |
| DeepETA transformer | Highest-QPS model at Uber; residual accuracy on top of routing | Two-layer ETA seam; record quoted vs actual |
| Michelangelo / Canvas | Training + serving hundreds of models globally | Nothing. No models in v1. |
| RAMEN / Streamgate / Helix / ZooKeeper / Cassandra | 250k msg/s, 1.5M sockets, multi-region | `ws` gateway in the existing NestJS process |
| Schemaless datastore | Sharded MySQL as a KV store, pre-2014 | PostgreSQL |
| Ringpop gossip membership | Decentralised sharding for early services | A single process |
| DynamoDB entity rows + LedgerStore | 1.2B entities, tamper-evident audit | PostgreSQL + append-only entries |
| Kafka / Cadence in payments | Cross-service async money movement | One transaction, one row lock |
| Error-claim headers over a service mesh | Call chains 25 levels deep | Correct retry layer; three hops |

---

## 10. Concrete backlog candidates

Derived from the above, ordered by (value ÷ cost) at Mishwar's current stage.
None of these are commitments; they are the parts of the corpus that actually cash
out.

> **Every row was checked against the schema and code, not assumed.** Three items
> from an earlier draft of this table were removed because the work was already
> done: `driver_location_updates` already carries `accuracy_m` / `recorded_at`,
> `ride_offers` already has `expires_at`, `notifications` already has a
> `dedupe_key` with a unique partial index, and `saved_places` already exists with
> customer CRUD. That pattern — the schema being ahead of the documentation about it
> — is itself worth knowing.

| # | Change | Module | Why it matters | Cost |
|---|---|---|---|---|
| 1 | Populate `ride_offers.eta_seconds_estimate`, then carry it onto the ride at assignment | `Dispatch` → `Trips` | **The column exists and is never written** — it is always `NULL` because `dispatch.service.ts` does not set it. Until a quoted ETA is recorded at assignment, no ETA work is ever justifiable (DeepETA's premise). | ~10 lines + 1 column on `rides` |
| 2 | Dead-reckoning check in candidate ranking | `Dispatch` | Ranking is `ORDER BY distance_m` over `ST_Distance` alone. A 200 m junk fix beats a good one, and `accuracy_m` is captured but never used for ranking. beacon's lesson, no hardware. | ~20 lines |
| 3 | Build the realtime layer to the § 6 spec: `ride_version`, heartbeat, dead-connection threshold, one payload builder for REST and push | new gateway module | **No WebSocket gateway exists yet** (`architecture.md` § 6 specifies it; nothing implements it). Building it to RAMEN's contracts now costs nothing extra; retrofitting them later costs a migration of every client. | new module |
| 4 | `expires_at` on pushed notification payloads | `Notifications` | `dedupe_key` is handled; staleness is not. A late "new offer" push makes a driver act on dead state. RAMEN's TTL policy. | 1 column |
| 5 | Wire `saved_places` into ride creation and show the label to the driver | `RideRequests` | Table and customer CRUD exist; the request flow does not use them. This is the actual Yemen pickup failure mode — metres of signal accuracy do not help a rider who cannot name the door. | 1 endpoint + 2 screens |
| 6 | ETA adjustment seam (identity for now) | `Pricing` / routing adapter | Makes room for Goldeta-style residuals without a rewrite. | Interface only |
| 7 | Routing adapter, invoked for the offered batch only | `Dispatch` | Gurafu's cost ceiling: routing inside the candidate scan multiplies by candidates × rounds. | Adapter + cache |
| 8 | Decide and document whether `rides.commission_amount` or the ledger is the revenue source of truth (§ 6) | `DriverWallet` / ADR-0005 | The ledger is single-entry, so commission is not in it. Ambiguity here becomes an unexplainable reconciliation gap. | 1 paragraph |

Items 1, 3 and 8 share a property that makes them urgent rather than tidy: they are
all cases where *delay is expensive in a way you cannot undo later*. Data you did
not record is not retroactively recoverable, and a client contract shipped without a
version field has to be re-shipped to every installed app. Items 2, 4, 5, 6 and 7 can
all be added the day they are needed.

---

## 11. Open questions this reading did not settle

Recorded honestly rather than papered over:

- **The dispatch/matching corpus was not readable.** Archive pagination stops at
  page 13 (2023-12-28), and the ride-hailing core lives in 2014–2022. The slugs are
  known (`simulated-marketplace`, `reinforcement-learning-for-modeling-marketplace-balance`,
  `better-load-balancing-real-time-dynamic-subsetting`, `go-geofence-highest-query-per-second-service`)
  but the posts have not been read. Any claim about Uber's *matching algorithm*
  here would be inference from titles, not evidence. See
  [`INDEX.md` § Coverage limit](./INDEX.md#coverage-limit).
- **Surge pricing mechanics are unread.** H3 establishes that surge is computed over
  hexagons, but the pricing model itself is in unread posts. Mishwar has no surge in
  v1, so this is deferred rather than blocked.
- **The checkout / instrument-selection layer is unread.** § 6 covers the ledger
  platform, which is the part Mishwar needs. `unified-checkout` (2024, indexed as
  row 106) covers instrument selection and payment-session flow — irrelevant while
  electronic payment is out of scope behind an adapter.
- **The realtime layer is specified but not built.** § 3's RAMEN analysis is
  necessarily forward-looking: `architecture.md` § 6 describes a `ride_version`
  contract and `GET /v1/rides/active` recovery, but no WebSocket gateway exists in
  `apps/api/src/modules`. The contract has not yet met a running socket, so its
  ergonomics are unproven.
- **Nothing here covers cash-first marketplaces.** Every payment and fraud pattern in
  the corpus assumes the platform is the merchant of record. Yemen is not that. The
  `CASH_COLLECTED` design in § 6 was arrived at independently by this codebase and
  has no counterpart in the Uber corpus — treat it as original design worth
  defending, and be cautious about importing payment reasoning wholesale.

---

## Sources

All links canonicalised to `www.uber.com/blog/<slug>/`; `eng.uber.com` redirects
there.

- Brodsky, I. (2018). [H3: Uber's Hexagonal Hierarchical Spatial Index](https://www.uber.com/blog/h3/)
- Shekhar, H. & Sankaravadivel, V. (2019). [Improving Pickups with Better Location Accuracy](https://www.uber.com/blog/beacon-improving-pickups-with-better-location-accuracy/)
- Thangavelu, M., Raja, A. & Mahajan, N. (2020). [Uber's Real-Time Push Platform](https://www.uber.com/blog/real-time-push-platform/)
- Uber AI & Maps (2022). [DeepETA: How Uber Predicts Arrival Times Using Deep Learning](https://www.uber.com/blog/deepeta-how-uber-predicts-arrival-times/)
- Nguyen, T. (2016). [Engineering the Routing Engine](https://www.uber.com/blog/engineering-routing-engine/)
- Sheth, N., Kelshikar, M. & Singh, D. (2026). [Zero Sum by Design: 10 Years of Uber's Payments Platform](https://www.uber.com/blog/ubers-payments-platform/)
- Mehndiratta, D., Srivastava, A. & Dhingra, V. (2026). [How Uber Protects Against Retry Storms](https://www.uber.com/blog/protecting-against-retry-storms/)
