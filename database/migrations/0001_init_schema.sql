-- =============================================================================
-- Mishwar Yemen — 0001_init_schema.sql
-- Requires PostgreSQL 15+ and PostGIS 3.x. Apply with database/run-migrations.sh.
--
-- STATUS: written and reviewed by hand; NOT yet executed against a live
-- PostgreSQL instance (the authoring sandbox had no PostgreSQL/network).
-- First action on a machine with Docker: `docker compose up -d db` and run it.
--
-- Conventions
--   * Times are timestamptz (stored UTC); display uses service_areas.timezone.
--   * Money is NUMERIC(18,2) with a currency_code on every financial row.
--     Application code converts to integer minor units (see docs/database-design.md).
--   * Status/enum-like columns are TEXT + CHECK (cheap to evolve in migrations).
--   * Nothing financial or ride-related is hard-deleted (see 0002 guards).
--   * Pricing/dispatch numbers are never defaulted here: they are configuration.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;

-- -----------------------------------------------------------------------------
-- Reference data
-- -----------------------------------------------------------------------------
CREATE TABLE currencies (
  code               text PRIMARY KEY CHECK (code ~ '^[A-Z]{3}$'),
  minor_unit_digits  smallint NOT NULL CHECK (minor_unit_digits BETWEEN 0 AND 2),
  is_active          boolean NOT NULL DEFAULT true
);

CREATE TABLE service_areas (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code           text NOT NULL UNIQUE CHECK (code ~ '^[A-Z0-9_]{2,32}$'),
  name_ar        text NOT NULL,
  name_en        text NOT NULL,
  boundary       geography(MultiPolygon, 4326) NOT NULL,
  timezone       text NOT NULL,                       -- IANA name, used only for display/reporting
  currency_code  text NOT NULL REFERENCES currencies(code),
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX service_areas_boundary_gix ON service_areas USING gist (boundary);

-- Dispatch tuning per service area. No defaults on purpose: operations must choose.
CREATE TABLE dispatch_settings (
  service_area_id          uuid PRIMARY KEY REFERENCES service_areas(id),
  search_radius_m          integer  NOT NULL CHECK (search_radius_m > 0),
  max_candidates           smallint NOT NULL CHECK (max_candidates > 0),
  offer_batch_size         smallint NOT NULL CHECK (offer_batch_size > 0),
  offer_ttl_seconds        smallint NOT NULL CHECK (offer_ttl_seconds > 0),
  search_timeout_seconds   integer  NOT NULL CHECK (search_timeout_seconds > 0),
  location_max_age_seconds integer  NOT NULL CHECK (location_max_age_seconds > 0),
  start_code_ttl_minutes   smallint NOT NULL CHECK (start_code_ttl_minutes > 0),
  start_code_max_attempts  smallint NOT NULL CHECK (start_code_max_attempts > 0),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CHECK (offer_batch_size <= max_candidates)
);

CREATE TABLE vehicle_types (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text NOT NULL UNIQUE CHECK (code ~ '^[A-Z0-9_]{2,32}$'),
  name_ar     text NOT NULL,
  name_en     text NOT NULL,
  capacity    smallint NOT NULL CHECK (capacity > 0),
  sort_order  smallint NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true
);

-- Admin-configurable document catalogue. Which documents are legally required
-- is a business/legal decision: nothing here asserts it.
CREATE TABLE document_types (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code             text NOT NULL UNIQUE CHECK (code ~ '^[A-Z0-9_]{2,48}$'),
  name_ar          text NOT NULL,
  name_en          text NOT NULL,
  applies_to       text NOT NULL CHECK (applies_to IN ('DRIVER', 'VEHICLE')),
  is_required      boolean NOT NULL,
  requires_expiry  boolean NOT NULL DEFAULT false,
  is_active        boolean NOT NULL DEFAULT true,
  sort_order       smallint NOT NULL DEFAULT 0
);

-- -----------------------------------------------------------------------------
-- Identity & access
-- -----------------------------------------------------------------------------
CREATE TABLE users (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_e164          text UNIQUE CHECK (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  phone_verified_at   timestamptz,
  email               text UNIQUE CHECK (email = lower(email)),
  password_hash       text,                              -- staff only (Argon2id); NULL for phone-only users
  display_name        text,
  locale              text NOT NULL DEFAULT 'ar' CHECK (locale IN ('ar', 'en')),
  status              text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
  failed_login_count  integer NOT NULL DEFAULT 0 CHECK (failed_login_count >= 0),
  locked_until        timestamptz,
  last_login_at       timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz,
  -- A deleted (anonymised) user may have neither identifier.
  CONSTRAINT users_has_identifier CHECK (status = 'DELETED' OR phone_e164 IS NOT NULL OR email IS NOT NULL),
  CONSTRAINT users_deleted_has_timestamp CHECK (status <> 'DELETED' OR deleted_at IS NOT NULL)
);

-- A person can hold several roles (e.g. CUSTOMER and DRIVER on one phone number).
-- Staff roles require email + password_hash: enforced in the service layer.
CREATE TABLE user_roles (
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN (
                'CUSTOMER', 'DRIVER', 'SUPPORT_AGENT', 'OPERATIONS_MANAGER',
                'FINANCE_MANAGER', 'ADMIN', 'SUPER_ADMIN')),
  granted_by  uuid REFERENCES users(id),
  granted_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role)
);

CREATE TABLE otp_challenges (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_e164    text NOT NULL CHECK (phone_e164 ~ '^\+[1-9][0-9]{7,14}$'),
  purpose       text NOT NULL CHECK (purpose IN ('LOGIN', 'VERIFY_PHONE')),
  code_hash     text NOT NULL,                           -- never the plaintext code
  attempts      smallint NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  max_attempts  smallint NOT NULL CHECK (max_attempts > 0),
  expires_at    timestamptz NOT NULL,
  consumed_at   timestamptz,
  requested_ip  inet,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at)
);
CREATE INDEX otp_challenges_phone_created_idx ON otp_challenges (phone_e164, created_at DESC);

-- Refresh-token rotation with reuse detection: presenting a token whose
-- rotated_at is set revokes the whole family_id.
CREATE TABLE refresh_tokens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  family_id       uuid NOT NULL,
  token_hash      text NOT NULL UNIQUE,
  device_id       text,
  expires_at      timestamptz NOT NULL,
  rotated_at      timestamptz,
  revoked_at      timestamptz,
  revoked_reason  text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_user_idx   ON refresh_tokens (user_id);
CREATE INDEX refresh_tokens_family_idx ON refresh_tokens (family_id);

CREATE TABLE device_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform    text NOT NULL CHECK (platform IN ('ANDROID', 'IOS')),
  token       text NOT NULL UNIQUE,
  locale      text NOT NULL DEFAULT 'ar' CHECK (locale IN ('ar', 'en')),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX device_tokens_user_idx ON device_tokens (user_id) WHERE revoked_at IS NULL;

-- -----------------------------------------------------------------------------
-- Profiles, vehicles, documents
-- -----------------------------------------------------------------------------
CREATE TABLE customer_profiles (
  user_id     uuid PRIMARY KEY REFERENCES users(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE saved_places (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id   uuid NOT NULL REFERENCES customer_profiles(user_id),
  label         text NOT NULL CHECK (length(btrim(label)) > 0),
  address_text  text,
  location      geography(Point, 4326) NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX saved_places_customer_idx ON saved_places (customer_id);

CREATE TABLE driver_profiles (
  user_id                    uuid PRIMARY KEY REFERENCES users(id),
  full_name                  text NOT NULL,
  service_area_id            uuid NOT NULL REFERENCES service_areas(id),
  verification_status        text NOT NULL DEFAULT 'PENDING'
                               CHECK (verification_status IN ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED')),
  verification_reviewed_by   uuid REFERENCES users(id),
  verification_reviewed_at   timestamptz,
  verification_note          text,
  suspension_reason          text,
  is_online                  boolean NOT NULL DEFAULT false,
  last_location              geography(Point, 4326),
  last_location_at           timestamptz,
  last_location_accuracy_m   real CHECK (last_location_accuracy_m IS NULL OR last_location_accuracy_m >= 0),
  rating_avg                 numeric(3,2) CHECK (rating_avg IS NULL OR rating_avg BETWEEN 1 AND 5),
  rating_count               integer NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT driver_online_requires_approval CHECK (NOT is_online OR verification_status = 'APPROVED'),
  CONSTRAINT driver_suspended_has_reason     CHECK (verification_status <> 'SUSPENDED' OR suspension_reason IS NOT NULL),
  CONSTRAINT driver_reviewed_has_reviewer    CHECK (verification_status = 'PENDING'
                                                    OR (verification_reviewed_by IS NOT NULL AND verification_reviewed_at IS NOT NULL)),
  CONSTRAINT driver_location_pair            CHECK ((last_location IS NULL) = (last_location_at IS NULL))
);
-- Dispatch candidate lookup: only online drivers with a known position.
CREATE INDEX driver_profiles_online_location_gix ON driver_profiles USING gist (last_location)
  WHERE is_online AND last_location IS NOT NULL;
CREATE INDEX driver_profiles_status_idx ON driver_profiles (verification_status);

CREATE TABLE vehicles (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id        uuid NOT NULL REFERENCES driver_profiles(user_id),
  vehicle_type_id  uuid NOT NULL REFERENCES vehicle_types(id),
  plate_number     text NOT NULL CHECK (length(btrim(plate_number)) > 0 AND plate_number = btrim(plate_number)),
  make             text,
  model            text,
  year             smallint CHECK (year IS NULL OR year BETWEEN 1960 AND 2100),
  color            text,
  is_active        boolean NOT NULL DEFAULT true,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
-- ASSUMPTION TO CONFIRM LOCALLY: plate numbers are unique across the platform among active vehicles.
-- If plates repeat across governorates, widen this index to include a governorate/area column.
CREATE UNIQUE INDEX vehicles_active_plate_uq          ON vehicles (plate_number) WHERE is_active;
CREATE UNIQUE INDEX vehicles_one_active_per_driver_uq ON vehicles (driver_id)    WHERE is_active;

CREATE TABLE driver_documents (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id         uuid NOT NULL REFERENCES driver_profiles(user_id),
  vehicle_id        uuid REFERENCES vehicles(id),
  document_type_id  uuid NOT NULL REFERENCES document_types(id),
  storage_key       text NOT NULL UNIQUE,                -- object-storage key, never a public URL
  mime_type         text NOT NULL CHECK (mime_type IN ('image/jpeg', 'image/png', 'application/pdf')),
  status            text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
  expires_on        date,
  reviewed_by       uuid REFERENCES users(id),
  reviewed_at       timestamptz,
  rejection_reason  text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT driver_documents_rejection_reason CHECK (status <> 'REJECTED' OR rejection_reason IS NOT NULL),
  CONSTRAINT driver_documents_reviewed         CHECK (status = 'PENDING' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);
CREATE INDEX driver_documents_driver_idx ON driver_documents (driver_id, document_type_id);
CREATE INDEX driver_documents_pending_idx ON driver_documents (created_at) WHERE status = 'PENDING';

-- -----------------------------------------------------------------------------
-- Pricing (rules are versioned and immutable once published: see 0002)
-- -----------------------------------------------------------------------------
CREATE TABLE pricing_rules (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_area_id    uuid NOT NULL REFERENCES service_areas(id),
  vehicle_type_id    uuid NOT NULL REFERENCES vehicle_types(id),
  version            integer NOT NULL CHECK (version >= 1),
  mode               text NOT NULL CHECK (mode IN ('FIXED_ROUTE', 'DISTANCE_TIME', 'MANUAL')),
  currency_code      text NOT NULL REFERENCES currencies(code),
  base_fare          numeric(18,2) NOT NULL CHECK (base_fare >= 0),
  per_km             numeric(18,2) NOT NULL CHECK (per_km >= 0),
  per_minute         numeric(18,2) NOT NULL CHECK (per_minute >= 0),
  minimum_fare       numeric(18,2) NOT NULL CHECK (minimum_fare >= 0),
  surcharges         jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(surcharges) = 'array'),
  commission_bps     integer NOT NULL CHECK (commission_bps BETWEEN 0 AND 10000),
  rounding_step      numeric(18,2) NOT NULL DEFAULT 1 CHECK (rounding_step > 0),
  status             text NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'ACTIVE', 'RETIRED')),
  effective_from     timestamptz,
  effective_to       timestamptz,
  created_by         uuid NOT NULL REFERENCES users(id),
  published_by       uuid REFERENCES users(id),
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (service_area_id, vehicle_type_id, version),
  CONSTRAINT pricing_rules_published_fields CHECK (status = 'DRAFT' OR (effective_from IS NOT NULL AND published_by IS NOT NULL)),
  CONSTRAINT pricing_rules_period           CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to > effective_from)
);
-- Exactly one ACTIVE rule per (area, vehicle type).
CREATE UNIQUE INDEX pricing_rules_one_active_uq ON pricing_rules (service_area_id, vehicle_type_id) WHERE status = 'ACTIVE';

-- Fixed-fare route pairs. A match overrides distance/time pricing for that rule.
CREATE TABLE fixed_routes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pricing_rule_id   uuid NOT NULL REFERENCES pricing_rules(id),
  name_ar           text NOT NULL,
  name_en           text,
  origin_zone       geography(Polygon, 4326) NOT NULL,
  destination_zone  geography(Polygon, 4326) NOT NULL,
  fare              numeric(18,2) NOT NULL CHECK (fare >= 0),
  created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX fixed_routes_rule_idx      ON fixed_routes (pricing_rule_id);
CREATE INDEX fixed_routes_origin_gix    ON fixed_routes USING gist (origin_zone);
CREATE INDEX fixed_routes_dest_gix      ON fixed_routes USING gist (destination_zone);

-- -----------------------------------------------------------------------------
-- Rides, events, offers
-- -----------------------------------------------------------------------------
CREATE TABLE rides (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_number             bigint GENERATED ALWAYS AS IDENTITY UNIQUE,   -- human-facing reference
  customer_id             uuid NOT NULL REFERENCES customer_profiles(user_id),
  driver_id               uuid REFERENCES driver_profiles(user_id),
  vehicle_id              uuid REFERENCES vehicles(id),
  service_area_id         uuid NOT NULL REFERENCES service_areas(id),
  vehicle_type_id         uuid NOT NULL REFERENCES vehicle_types(id),
  status                  text NOT NULL CHECK (status IN (
                            'SEARCHING', 'NO_DRIVER_FOUND', 'ASSIGNED', 'ARRIVING',
                            'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
  pickup                  geography(Point, 4326) NOT NULL,
  pickup_address          text,
  destination             geography(Point, 4326) NOT NULL,
  destination_address     text,
  payment_method          text NOT NULL DEFAULT 'CASH' CHECK (payment_method IN ('CASH')),
  currency_code           text NOT NULL REFERENCES currencies(code),
  pricing_rule_id         uuid NOT NULL REFERENCES pricing_rules(id),
  pricing_rule_version    integer NOT NULL,
  price_breakdown         jsonb NOT NULL,                 -- full snapshot from the pricing engine
  quoted_total            numeric(18,2) NOT NULL CHECK (quoted_total >= 0),
  final_total             numeric(18,2) CHECK (final_total IS NULL OR final_total >= 0),
  commission_amount       numeric(18,2) CHECK (commission_amount IS NULL OR commission_amount >= 0),
  driver_net              numeric(18,2) CHECK (driver_net IS NULL OR driver_net >= 0),
  estimated_distance_m    integer NOT NULL CHECK (estimated_distance_m >= 0),
  estimated_duration_s    integer NOT NULL CHECK (estimated_duration_s >= 0),
  actual_distance_m       integer CHECK (actual_distance_m IS NULL OR actual_distance_m >= 0),
  actual_duration_s       integer CHECK (actual_duration_s IS NULL OR actual_duration_s >= 0),
  start_code_nonce        bytea,                          -- the code itself is derived (HMAC), never stored
  start_code_expires_at   timestamptz,
  start_code_attempts     smallint NOT NULL DEFAULT 0 CHECK (start_code_attempts >= 0),
  search_expires_at       timestamptz NOT NULL,
  cancelled_by_role       text CHECK (cancelled_by_role IS NULL OR cancelled_by_role IN ('CUSTOMER', 'DRIVER', 'SYSTEM', 'STAFF')),
  cancelled_by_user_id    uuid REFERENCES users(id),
  cancel_reason_code      text,
  cancel_note             text,
  requested_at            timestamptz NOT NULL DEFAULT now(),
  assigned_at             timestamptz,
  arrived_at              timestamptz,
  started_at              timestamptz,
  completed_at            timestamptz,
  cancelled_at            timestamptz,
  version                 integer NOT NULL DEFAULT 0,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT rides_no_driver_while_searching CHECK (
    status NOT IN ('SEARCHING', 'NO_DRIVER_FOUND') OR (driver_id IS NULL AND vehicle_id IS NULL)),
  CONSTRAINT rides_driver_when_assigned CHECK (
    status NOT IN ('ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED')
    OR (driver_id IS NOT NULL AND vehicle_id IS NOT NULL AND assigned_at IS NOT NULL)),
  CONSTRAINT rides_start_code_when_assigned CHECK (
    status NOT IN ('ASSIGNED', 'ARRIVING', 'ARRIVED')
    OR (start_code_nonce IS NOT NULL AND start_code_expires_at IS NOT NULL)),
  CONSTRAINT rides_in_progress_has_start CHECK (status NOT IN ('IN_PROGRESS', 'COMPLETED') OR started_at IS NOT NULL),
  CONSTRAINT rides_completed_has_totals CHECK (
    status <> 'COMPLETED'
    OR (final_total IS NOT NULL AND commission_amount IS NOT NULL AND driver_net IS NOT NULL
        AND completed_at IS NOT NULL AND commission_amount + driver_net = final_total)),
  CONSTRAINT rides_cancelled_has_audit CHECK (
    status <> 'CANCELLED'
    OR (cancelled_at IS NOT NULL AND cancelled_by_role IS NOT NULL AND cancel_reason_code IS NOT NULL)),
  CONSTRAINT rides_pickup_differs_from_destination CHECK (NOT ST_Equals(pickup::geometry, destination::geometry))
);
-- A driver can have at most one live trip; a customer at most one live request.
CREATE UNIQUE INDEX rides_one_active_per_driver_uq
  ON rides (driver_id) WHERE status IN ('ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS');
CREATE UNIQUE INDEX rides_one_active_per_customer_uq
  ON rides (customer_id) WHERE status IN ('SEARCHING', 'ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS');
CREATE INDEX rides_customer_history_idx ON rides (customer_id, requested_at DESC);
CREATE INDEX rides_driver_history_idx   ON rides (driver_id, requested_at DESC) WHERE driver_id IS NOT NULL;
CREATE INDEX rides_searching_idx        ON rides (service_area_id, requested_at) WHERE status = 'SEARCHING';
CREATE INDEX rides_status_area_idx      ON rides (service_area_id, status, requested_at DESC);
CREATE INDEX rides_pickup_gix           ON rides USING gist (pickup);

-- Append-only timeline (UPDATE/DELETE rejected in 0002).
CREATE TABLE ride_events (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ride_id          uuid NOT NULL REFERENCES rides(id),
  event_type       text NOT NULL,
  from_status      text,
  to_status        text,
  actor_role       text NOT NULL CHECK (actor_role IN ('CUSTOMER', 'DRIVER', 'SYSTEM', 'STAFF')),
  actor_user_id    uuid REFERENCES users(id),
  client_event_id  uuid,                                  -- lets a retried client event be recognised
  payload          jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ride_events_ride_idx ON ride_events (ride_id, id);
CREATE UNIQUE INDEX ride_events_client_event_uq ON ride_events (ride_id, client_event_id) WHERE client_event_id IS NOT NULL;

CREATE TABLE ride_offers (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id                 uuid NOT NULL REFERENCES rides(id),
  driver_id               uuid NOT NULL REFERENCES driver_profiles(user_id),
  status                  text NOT NULL DEFAULT 'PENDING'
                            CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELLED')),
  round_no                smallint NOT NULL CHECK (round_no >= 1),
  distance_to_pickup_m    integer CHECK (distance_to_pickup_m IS NULL OR distance_to_pickup_m >= 0),
  eta_seconds_estimate    integer CHECK (eta_seconds_estimate IS NULL OR eta_seconds_estimate >= 0),
  driver_location_age_s   integer CHECK (driver_location_age_s IS NULL OR driver_location_age_s >= 0),
  offered_at              timestamptz NOT NULL DEFAULT now(),
  expires_at              timestamptz NOT NULL,
  responded_at            timestamptz,
  UNIQUE (ride_id, driver_id),                            -- a driver is offered a given ride once
  CONSTRAINT ride_offers_expiry_after_offer CHECK (expires_at > offered_at),
  CONSTRAINT ride_offers_responded CHECK (status = 'PENDING' OR responded_at IS NOT NULL OR status IN ('EXPIRED', 'CANCELLED'))
);
-- At most one accepted offer per ride, enforced by the database.
CREATE UNIQUE INDEX ride_offers_one_accepted_uq ON ride_offers (ride_id) WHERE status = 'ACCEPTED';
CREATE INDEX ride_offers_driver_pending_idx ON ride_offers (driver_id, expires_at) WHERE status = 'PENDING';
CREATE INDEX ride_offers_sweep_idx          ON ride_offers (expires_at) WHERE status = 'PENDING';

-- Raw GPS history. Retention job deletes rows older than the configured window
-- (docs/security.md §Location data). Candidate for time partitioning at scale.
CREATE TABLE driver_location_updates (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  driver_id    uuid NOT NULL REFERENCES driver_profiles(user_id),
  ride_id      uuid REFERENCES rides(id),
  location     geography(Point, 4326) NOT NULL,
  accuracy_m   real CHECK (accuracy_m IS NULL OR accuracy_m >= 0),
  speed_mps    real CHECK (speed_mps IS NULL OR speed_mps >= 0),
  heading_deg  real CHECK (heading_deg IS NULL OR heading_deg >= 0 AND heading_deg <= 360),
  recorded_at  timestamptz NOT NULL,                      -- device clock
  received_at  timestamptz NOT NULL DEFAULT now()         -- server clock
);
CREATE INDEX driver_location_updates_driver_time_idx ON driver_location_updates (driver_id, recorded_at DESC);
CREATE INDEX driver_location_updates_ride_idx        ON driver_location_updates (ride_id, recorded_at) WHERE ride_id IS NOT NULL;
CREATE INDEX driver_location_updates_recorded_brin   ON driver_location_updates USING brin (recorded_at);

-- -----------------------------------------------------------------------------
-- Money
-- -----------------------------------------------------------------------------
CREATE TABLE payment_records (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id             uuid NOT NULL UNIQUE REFERENCES rides(id),
  method              text NOT NULL CHECK (method IN ('CASH', 'ONLINE')),
  status              text NOT NULL DEFAULT 'PENDING'
                        CHECK (status IN ('PENDING', 'COLLECTED_BY_DRIVER', 'RECONCILED', 'DISPUTED', 'VOID')),
  amount              numeric(18,2) NOT NULL CHECK (amount >= 0),
  currency_code       text NOT NULL REFERENCES currencies(code),
  provider            text,
  provider_reference  text,
  collected_at        timestamptz,
  reconciled_by       uuid REFERENCES users(id),
  reconciled_at       timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  -- A cash payment is never presented as confirmed by an online provider.
  CONSTRAINT payment_cash_has_no_provider CHECK (method <> 'CASH' OR (provider IS NULL AND provider_reference IS NULL)),
  CONSTRAINT payment_reconciled_has_reviewer CHECK (status <> 'RECONCILED' OR (reconciled_by IS NOT NULL AND reconciled_at IS NOT NULL)),
  CONSTRAINT payment_collected_has_time CHECK (status NOT IN ('COLLECTED_BY_DRIVER', 'RECONCILED') OR collected_at IS NOT NULL)
);
CREATE UNIQUE INDEX payment_records_provider_ref_uq ON payment_records (provider, provider_reference) WHERE provider_reference IS NOT NULL;
CREATE INDEX payment_records_status_idx ON payment_records (status, created_at);

CREATE TABLE driver_payouts (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id      uuid NOT NULL REFERENCES driver_profiles(user_id),
  direction      text NOT NULL CHECK (direction IN ('DRIVER_TO_PLATFORM', 'PLATFORM_TO_DRIVER')),
  amount         numeric(18,2) NOT NULL CHECK (amount > 0),
  currency_code  text NOT NULL REFERENCES currencies(code),
  status         text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'COMPLETED', 'REJECTED', 'VOID')),
  method         text,
  reference      text,
  note           text,
  requested_by   uuid NOT NULL REFERENCES users(id),
  reviewed_by    uuid REFERENCES users(id),
  reviewed_at    timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  -- Four-eyes: the reviewer cannot be the requester.
  CONSTRAINT payouts_four_eyes CHECK (reviewed_by IS NULL OR reviewed_by <> requested_by),
  CONSTRAINT payouts_reviewed  CHECK (status IN ('PENDING', 'VOID') OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);
CREATE INDEX driver_payouts_driver_idx ON driver_payouts (driver_id, created_at DESC);
CREATE INDEX driver_payouts_pending_idx ON driver_payouts (created_at) WHERE status = 'PENDING';

-- Sign convention: amount > 0 => platform owes driver; amount < 0 => driver owes platform.
-- Append-only. Corrections are REVERSAL / ADJUSTMENT entries (see 0002 guards).
CREATE TABLE driver_ledger_entries (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  driver_id          uuid NOT NULL REFERENCES driver_profiles(user_id),
  ride_id            uuid REFERENCES rides(id),
  payout_id          uuid REFERENCES driver_payouts(id),
  entry_type         text NOT NULL CHECK (entry_type IN (
                       'EARNING', 'CASH_COLLECTED', 'SETTLEMENT_FROM_DRIVER',
                       'SETTLEMENT_TO_DRIVER', 'ADJUSTMENT', 'REVERSAL')),
  amount             numeric(18,2) NOT NULL CHECK (amount <> 0),
  currency_code      text NOT NULL REFERENCES currencies(code),
  idempotency_key    text NOT NULL UNIQUE,
  reverses_entry_id  bigint UNIQUE REFERENCES driver_ledger_entries(id),
  memo               text,
  created_by         uuid REFERENCES users(id),
  created_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ledger_ride_entries_have_ride CHECK (entry_type NOT IN ('EARNING', 'CASH_COLLECTED') OR ride_id IS NOT NULL),
  CONSTRAINT ledger_settlements_have_payout CHECK (entry_type NOT IN ('SETTLEMENT_FROM_DRIVER', 'SETTLEMENT_TO_DRIVER') OR payout_id IS NOT NULL),
  CONSTRAINT ledger_reversal_links_entry CHECK (entry_type <> 'REVERSAL' OR reverses_entry_id IS NOT NULL),
  CONSTRAINT ledger_manual_entries_have_author CHECK (entry_type NOT IN ('ADJUSTMENT', 'REVERSAL') OR (created_by IS NOT NULL AND memo IS NOT NULL))
);
-- Belt and braces next to the idempotency key: one EARNING and one CASH_COLLECTED per ride.
CREATE UNIQUE INDEX ledger_one_ride_entry_per_type_uq
  ON driver_ledger_entries (ride_id, entry_type) WHERE entry_type IN ('EARNING', 'CASH_COLLECTED');
CREATE INDEX driver_ledger_driver_idx ON driver_ledger_entries (driver_id, created_at);

CREATE VIEW driver_balances AS
  SELECT driver_id,
         currency_code,
         SUM(amount)     AS balance,        -- > 0: platform owes driver; < 0: driver owes platform
         COUNT(*)        AS entry_count,
         MAX(created_at) AS last_entry_at
  FROM driver_ledger_entries
  GROUP BY driver_id, currency_code;

-- -----------------------------------------------------------------------------
-- Ratings, support, notifications, audit, idempotency
-- -----------------------------------------------------------------------------
CREATE TABLE ratings (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id     uuid NOT NULL REFERENCES rides(id),
  rater_id    uuid NOT NULL REFERENCES users(id),
  ratee_id    uuid NOT NULL REFERENCES users(id),
  rater_role  text NOT NULL CHECK (rater_role IN ('CUSTOMER', 'DRIVER')),
  score       smallint NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ride_id, rater_role),
  CHECK (rater_id <> ratee_id)
);
CREATE INDEX ratings_ratee_idx ON ratings (ratee_id);

CREATE TABLE support_tickets (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  ride_id      uuid REFERENCES rides(id),
  reporter_id  uuid NOT NULL REFERENCES users(id),
  category     text NOT NULL CHECK (category IN (
                 'SAFETY_INCIDENT', 'FARE_DISPUTE', 'DRIVER_BEHAVIOR',
                 'CUSTOMER_BEHAVIOR', 'PAYMENT', 'APP_ISSUE', 'OTHER')),
  status       text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
  subject      text NOT NULL CHECK (length(btrim(subject)) > 0),
  description  text NOT NULL,
  assigned_to  uuid REFERENCES users(id),
  resolved_at  timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT support_resolved_has_time CHECK (status NOT IN ('RESOLVED', 'CLOSED') OR resolved_at IS NOT NULL)
);
CREATE INDEX support_tickets_status_idx ON support_tickets (status, created_at);
CREATE INDEX support_tickets_ride_idx   ON support_tickets (ride_id) WHERE ride_id IS NOT NULL;

CREATE TABLE support_ticket_notes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id    uuid NOT NULL REFERENCES support_tickets(id),
  author_id    uuid NOT NULL REFERENCES users(id),
  body         text NOT NULL CHECK (length(btrim(body)) > 0),
  is_internal  boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX support_ticket_notes_ticket_idx ON support_ticket_notes (ticket_id, created_at);

CREATE TABLE notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id),
  kind        text NOT NULL,
  title       text NOT NULL,
  body        text NOT NULL,
  data        jsonb NOT NULL DEFAULT '{}'::jsonb,
  dedupe_key  text,
  push_status text NOT NULL DEFAULT 'NOT_REQUESTED' CHECK (push_status IN ('NOT_REQUESTED', 'PENDING', 'SENT', 'FAILED')),
  push_attempts smallint NOT NULL DEFAULT 0 CHECK (push_attempts >= 0),
  read_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX notifications_dedupe_uq ON notifications (user_id, dedupe_key) WHERE dedupe_key IS NOT NULL;
CREATE INDEX notifications_user_idx ON notifications (user_id, created_at DESC);

CREATE TABLE audit_logs (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_user_id  uuid REFERENCES users(id),
  actor_role     text,
  action         text NOT NULL,
  entity_type    text NOT NULL,
  entity_id      text,
  before_state   jsonb,
  after_state    jsonb,
  reason         text,
  ip             inet,
  user_agent     text,
  request_id     text,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_entity_idx ON audit_logs (entity_type, entity_id, created_at DESC);
CREATE INDEX audit_logs_actor_idx  ON audit_logs (actor_user_id, created_at DESC);
CREATE INDEX audit_logs_action_idx ON audit_logs (action, created_at DESC);

CREATE TABLE idempotency_keys (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES users(id),
  scope            text NOT NULL,                         -- e.g. 'POST /rides', 'POST /offers/:id/accept'
  idempotency_key  text NOT NULL CHECK (length(idempotency_key) BETWEEN 8 AND 128),
  request_hash     text NOT NULL,                         -- same key + different body => 422, not a replay
  state            text NOT NULL DEFAULT 'IN_PROGRESS' CHECK (state IN ('IN_PROGRESS', 'COMPLETED')),
  response_status  smallint,
  response_body    jsonb,
  resource_type    text,
  resource_id      uuid,
  created_at       timestamptz NOT NULL DEFAULT now(),
  expires_at       timestamptz NOT NULL,
  UNIQUE (user_id, scope, idempotency_key),
  CONSTRAINT idempotency_completed_has_response CHECK (state <> 'COMPLETED' OR response_status IS NOT NULL)
);
CREATE INDEX idempotency_keys_expires_idx ON idempotency_keys (expires_at);

INSERT INTO schema_migrations (version, description) VALUES ('0001', 'initial schema');

COMMIT;
