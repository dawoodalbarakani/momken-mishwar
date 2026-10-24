-- =============================================================================
-- Mishwar Yemen — 0002_integrity_guards.sql
-- Database-level backstops. The application enforces the same rules first
-- (apps/api/src/domain); these triggers make a bug or a manual SQL session
-- unable to corrupt rides, offers, pricing history, ledger or audit data.
--
-- STATUS: written and reviewed by hand; NOT yet executed (see 0001 header).
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. updated_at maintenance
-- -----------------------------------------------------------------------------
CREATE FUNCTION set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'users', 'service_areas', 'dispatch_settings', 'driver_profiles', 'vehicles',
    'payment_records', 'driver_payouts', 'support_tickets'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
      t || '_set_updated_at', t);
  END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. Append-only tables and no-delete tables
--    (dev resets should drop and recreate the database, not TRUNCATE)
-- -----------------------------------------------------------------------------
CREATE FUNCTION forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '% on % is not allowed: table is append-only', TG_OP, TG_TABLE_NAME
    USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE FUNCTION forbid_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'DELETE on % is not allowed: use status changes and retention policy instead', TG_TABLE_NAME
    USING ERRCODE = 'restrict_violation';
END;
$$;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['ride_events', 'audit_logs', 'driver_ledger_entries'] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION forbid_mutation()',
      t || '_append_only', t);
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE TRUNCATE ON %I FOR EACH STATEMENT EXECUTE FUNCTION forbid_mutation()',
      t || '_no_truncate', t);
  END LOOP;

  FOREACH t IN ARRAY ARRAY['rides', 'payment_records', 'driver_payouts', 'users'] LOOP
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE DELETE ON %I FOR EACH ROW EXECUTE FUNCTION forbid_delete()',
      t || '_no_delete', t);
  END LOOP;
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. Pricing rules: editable while DRAFT, immutable once published
-- -----------------------------------------------------------------------------
CREATE FUNCTION guard_pricing_rule() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'DRAFT' THEN
      RAISE EXCEPTION 'pricing rule % is % and cannot be deleted', OLD.id, OLD.status
        USING ERRCODE = 'restrict_violation';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD.status = 'DRAFT' THEN
    RETURN NEW;                         -- drafts are freely editable and can be published
  END IF;

  IF OLD.status = 'RETIRED' THEN
    RAISE EXCEPTION 'pricing rule % is RETIRED and immutable', OLD.id USING ERRCODE = 'restrict_violation';
  END IF;

  -- OLD.status = 'ACTIVE': only ACTIVE -> RETIRED (and effective_to) may change.
  IF NEW.status = 'DRAFT' THEN
    RAISE EXCEPTION 'pricing rule % cannot go back to DRAFT', OLD.id USING ERRCODE = 'restrict_violation';
  END IF;

  IF (NEW.service_area_id, NEW.vehicle_type_id, NEW.version, NEW.mode, NEW.currency_code,
      NEW.base_fare, NEW.per_km, NEW.per_minute, NEW.minimum_fare, NEW.surcharges,
      NEW.commission_bps, NEW.rounding_step, NEW.effective_from, NEW.created_by, NEW.published_by)
     IS DISTINCT FROM
     (OLD.service_area_id, OLD.vehicle_type_id, OLD.version, OLD.mode, OLD.currency_code,
      OLD.base_fare, OLD.per_km, OLD.per_minute, OLD.minimum_fare, OLD.surcharges,
      OLD.commission_bps, OLD.rounding_step, OLD.effective_from, OLD.created_by, OLD.published_by)
  THEN
    RAISE EXCEPTION 'published pricing rule % is immutable: create a new version instead', OLD.id
      USING ERRCODE = 'restrict_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER pricing_rules_guard
  BEFORE UPDATE OR DELETE ON pricing_rules
  FOR EACH ROW EXECUTE FUNCTION guard_pricing_rule();

CREATE FUNCTION guard_fixed_route() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  parent_id     uuid;
  parent_status text;
  parent_mode   text;
BEGIN
  parent_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.pricing_rule_id ELSE NEW.pricing_rule_id END;
  SELECT status, mode INTO parent_status, parent_mode FROM pricing_rules WHERE id = parent_id;

  IF parent_status IS DISTINCT FROM 'DRAFT' THEN
    RAISE EXCEPTION 'fixed routes can only change while their pricing rule is DRAFT'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF TG_OP <> 'DELETE' AND parent_mode NOT IN ('FIXED_ROUTE', 'DISTANCE_TIME') THEN
    RAISE EXCEPTION 'fixed routes require a FIXED_ROUTE or DISTANCE_TIME pricing rule'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;

CREATE TRIGGER fixed_routes_guard
  BEFORE INSERT OR UPDATE OR DELETE ON fixed_routes
  FOR EACH ROW EXECUTE FUNCTION guard_fixed_route();

-- -----------------------------------------------------------------------------
-- 4. Drivers: leaving APPROVED always takes the driver offline
-- -----------------------------------------------------------------------------
CREATE FUNCTION driver_force_offline() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.verification_status <> 'APPROVED' THEN
    NEW.is_online := false;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER driver_profiles_force_offline
  BEFORE INSERT OR UPDATE ON driver_profiles
  FOR EACH ROW EXECUTE FUNCTION driver_force_offline();

-- -----------------------------------------------------------------------------
-- 5. Rides: immutable fields, legal transitions, assignment preconditions
-- -----------------------------------------------------------------------------
CREATE FUNCTION guard_ride_update() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  d_status   text;
  d_online   boolean;
  d_area     uuid;
  u_status   text;
  v_ok       boolean;
BEGIN
  IF OLD.status IN ('COMPLETED', 'CANCELLED', 'NO_DRIVER_FOUND') THEN
    RAISE EXCEPTION 'ride % is % and can no longer change', OLD.id, OLD.status
      USING ERRCODE = 'restrict_violation';
  END IF;

  IF (NEW.id, NEW.ride_number, NEW.customer_id, NEW.service_area_id, NEW.vehicle_type_id,
      NEW.currency_code, NEW.pricing_rule_id, NEW.pricing_rule_version, NEW.price_breakdown,
      NEW.quoted_total, NEW.payment_method, NEW.requested_at, NEW.created_at,
      ST_AsBinary(NEW.pickup), ST_AsBinary(NEW.destination))
     IS DISTINCT FROM
     (OLD.id, OLD.ride_number, OLD.customer_id, OLD.service_area_id, OLD.vehicle_type_id,
      OLD.currency_code, OLD.pricing_rule_id, OLD.pricing_rule_version, OLD.price_breakdown,
      OLD.quoted_total, OLD.payment_method, OLD.requested_at, OLD.created_at,
      ST_AsBinary(OLD.pickup), ST_AsBinary(OLD.destination))
  THEN
    RAISE EXCEPTION 'ride % : request, route and price snapshot are immutable', OLD.id
      USING ERRCODE = 'restrict_violation';
  END IF;

  IF OLD.driver_id IS NOT NULL AND NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
    RAISE EXCEPTION 'ride % : driver cannot be changed once assigned (cancel and re-request)', OLD.id
      USING ERRCODE = 'restrict_violation';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF (OLD.status || '>' || NEW.status) <> ALL (ARRAY[
         'SEARCHING>ASSIGNED', 'SEARCHING>NO_DRIVER_FOUND', 'SEARCHING>CANCELLED',
         'ASSIGNED>ARRIVING',  'ASSIGNED>CANCELLED',
         'ARRIVING>ARRIVED',   'ARRIVING>CANCELLED',
         'ARRIVED>IN_PROGRESS','ARRIVED>CANCELLED',
         'IN_PROGRESS>COMPLETED', 'IN_PROGRESS>CANCELLED'])
    THEN
      RAISE EXCEPTION 'ride % : illegal transition % -> %', OLD.id, OLD.status, NEW.status
        USING ERRCODE = 'check_violation';
    END IF;

    -- Assignment preconditions, evaluated under a share lock on the driver row so a
    -- concurrent suspension/offline update has to wait for this transaction.
    IF OLD.status = 'SEARCHING' AND NEW.status = 'ASSIGNED' THEN
      SELECT dp.verification_status, dp.is_online, dp.service_area_id, u.status
        INTO d_status, d_online, d_area, u_status
        FROM driver_profiles dp
        JOIN users u ON u.id = dp.user_id
       WHERE dp.user_id = NEW.driver_id
         FOR SHARE OF dp;

      IF d_status IS DISTINCT FROM 'APPROVED' OR d_online IS DISTINCT FROM true OR u_status IS DISTINCT FROM 'ACTIVE' THEN
        RAISE EXCEPTION 'driver % is not approved, online and active', NEW.driver_id
          USING ERRCODE = 'check_violation';
      END IF;
      IF d_area IS DISTINCT FROM NEW.service_area_id THEN
        RAISE EXCEPTION 'driver % does not serve the ride''s service area', NEW.driver_id
          USING ERRCODE = 'check_violation';
      END IF;

      SELECT EXISTS (
        SELECT 1 FROM vehicles v
         WHERE v.id = NEW.vehicle_id
           AND v.driver_id = NEW.driver_id
           AND v.is_active
           AND v.vehicle_type_id = NEW.vehicle_type_id)
        INTO v_ok;
      IF NOT v_ok THEN
        RAISE EXCEPTION 'vehicle % is not an active vehicle of the requested type owned by driver %',
          NEW.vehicle_id, NEW.driver_id USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;

  NEW.version    := OLD.version + 1;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER rides_guard
  BEFORE UPDATE ON rides
  FOR EACH ROW EXECUTE FUNCTION guard_ride_update();

-- A ride is always born SEARCHING, with no driver, and with a fresh start-code state.
CREATE FUNCTION guard_ride_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status <> 'SEARCHING' THEN
    RAISE EXCEPTION 'a new ride must start as SEARCHING, got %', NEW.status
      USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.quoted_total IS NULL OR NEW.pricing_rule_id IS NULL THEN
    RAISE EXCEPTION 'a new ride must carry a server-computed price snapshot'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER rides_guard_insert
  BEFORE INSERT ON rides
  FOR EACH ROW EXECUTE FUNCTION guard_ride_insert();

-- -----------------------------------------------------------------------------
-- 6. Offers: only PENDING offers change; an expired offer can't be accepted;
--    an ACCEPTED offer must match the ride's driver by commit time.
-- -----------------------------------------------------------------------------
CREATE FUNCTION guard_ride_offer_update() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status <> 'PENDING' THEN
    RAISE EXCEPTION 'offer % is % and can no longer change', OLD.id, OLD.status
      USING ERRCODE = 'restrict_violation';
  END IF;

  IF (NEW.id, NEW.ride_id, NEW.driver_id, NEW.round_no, NEW.offered_at, NEW.expires_at)
     IS DISTINCT FROM
     (OLD.id, OLD.ride_id, OLD.driver_id, OLD.round_no, OLD.offered_at, OLD.expires_at)
  THEN
    RAISE EXCEPTION 'offer % : identity and expiry are immutable', OLD.id
      USING ERRCODE = 'restrict_violation';
  END IF;

  IF NEW.status = 'ACCEPTED' AND clock_timestamp() >= OLD.expires_at THEN
    RAISE EXCEPTION 'offer % expired at %', OLD.id, OLD.expires_at
      USING ERRCODE = 'check_violation';
  END IF;

  IF NEW.status <> 'PENDING' AND NEW.responded_at IS NULL THEN
    NEW.responded_at := clock_timestamp();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER ride_offers_guard
  BEFORE UPDATE ON ride_offers
  FOR EACH ROW EXECUTE FUNCTION guard_ride_offer_update();

CREATE FUNCTION check_accepted_offer_matches_ride() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'ACCEPTED' THEN
    PERFORM 1 FROM rides
     WHERE id = NEW.ride_id
       AND driver_id = NEW.driver_id
       AND status IN ('ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED');
    IF NOT FOUND THEN
      RAISE EXCEPTION 'accepted offer % does not match ride % assignment', NEW.id, NEW.ride_id
        USING ERRCODE = 'integrity_constraint_violation';
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER ride_offers_accepted_matches_ride
  AFTER INSERT OR UPDATE OF status ON ride_offers
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION check_accepted_offer_matches_ride();

-- -----------------------------------------------------------------------------
-- 7. Payments: identity and amount are fixed after creation
-- -----------------------------------------------------------------------------
CREATE FUNCTION guard_payment_record() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (NEW.ride_id, NEW.method, NEW.amount, NEW.currency_code)
     IS DISTINCT FROM
     (OLD.ride_id, OLD.method, OLD.amount, OLD.currency_code)
  THEN
    RAISE EXCEPTION 'payment % : ride, method, amount and currency are immutable (void and re-create)', OLD.id
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF OLD.status IN ('RECONCILED', 'VOID') AND NEW.status IS DISTINCT FROM OLD.status THEN
    RAISE EXCEPTION 'payment % is % and its status can no longer change', OLD.id, OLD.status
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER payment_records_guard
  BEFORE UPDATE ON payment_records
  FOR EACH ROW EXECUTE FUNCTION guard_payment_record();

INSERT INTO schema_migrations (version, description) VALUES ('0002', 'integrity guards');

COMMIT;
