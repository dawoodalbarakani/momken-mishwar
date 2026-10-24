-- =============================================================================
-- Mishwar Yemen — 001_reference_data.sql   (DEVELOPMENT / STAGING REFERENCE DATA)
--
-- Every number below is a SYNTHETIC PLACEHOLDER, not market data and not a
-- legal requirement. Operations must set real tariffs, boundaries, dispatch
-- limits and the document catalogue before launch (see docs/deployment.md).
-- The Sanaa boundary is a rough rectangle, not a surveyed city limit.
-- Users, drivers, vehicles, a sample (placeholder-priced) tariff and sample rides
-- are created by the TypeScript seed script (needs a staff user as created_by,
-- hashes passwords, refuses to run when NODE_ENV=production) — not here.
-- Idempotent: safe to re-run.
-- =============================================================================
BEGIN;

INSERT INTO currencies (code, minor_unit_digits, is_active) VALUES
  ('YER', 2, true),
  ('USD', 2, false),
  ('SAR', 2, false)
ON CONFLICT (code) DO NOTHING;

INSERT INTO service_areas (id, code, name_ar, name_en, boundary, timezone, currency_code) VALUES
  ('00000000-0000-4000-8000-000000000001', 'SANAA', 'صنعاء', 'Sanaa',
   ST_GeogFromText('SRID=4326;MULTIPOLYGON(((44.10 15.27, 44.29 15.27, 44.29 15.46, 44.10 15.46, 44.10 15.27)))'),
   'Asia/Aden', 'YER')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dispatch_settings (service_area_id, search_radius_m, max_candidates, offer_batch_size,
                               offer_ttl_seconds, search_timeout_seconds, location_max_age_seconds,
                               start_code_ttl_minutes, start_code_max_attempts) VALUES
  ('00000000-0000-4000-8000-000000000001', 3000, 5, 1, 20, 120, 30, 120, 5)
ON CONFLICT (service_area_id) DO NOTHING;

INSERT INTO vehicle_types (id, code, name_ar, name_en, capacity, sort_order) VALUES
  ('00000000-0000-4000-8000-000000000011', 'STANDARD', 'سيارة عادية', 'Standard car', 4, 1),
  ('00000000-0000-4000-8000-000000000012', 'FAMILY',   'سيارة عائلية', 'Family car',   6, 2)
ON CONFLICT (code) DO NOTHING;

-- Sample document catalogue. Admin-editable; NOT an assertion of legal requirements.
INSERT INTO document_types (code, name_ar, name_en, applies_to, is_required, requires_expiry, sort_order) VALUES
  ('DRIVER_LICENSE',       'رخصة القيادة',     'Driving licence',       'DRIVER',  true, true,  1),
  ('DRIVER_ID',            'وثيقة الهوية',     'Identity document',     'DRIVER',  true, false, 2),
  ('VEHICLE_REGISTRATION', 'استمارة المركبة',  'Vehicle registration',  'VEHICLE', true, true,  3)
ON CONFLICT (code) DO NOTHING;

COMMIT;
