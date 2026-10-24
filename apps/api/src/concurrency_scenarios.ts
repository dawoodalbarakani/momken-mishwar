import { Pool, PoolClient } from 'pg';

const DATABASE_URL = process.env.DATABASE_URL ?? 'postgres://mishwar:mishwar_test_only@localhost:5433/mishwar_test';

const pool = new Pool({ connectionString: DATABASE_URL, max: 10 });

const SANAA_ID = '00000000-0000-4000-8000-000000000001';
const STANDARD_ID = '00000000-0000-4000-8000-000000000011';

type OpResult = { rowCount: number; err: string | null };

async function withTxn<T>(fn: (c: PoolClient) => Promise<T>): Promise<T> {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    const result = await fn(c);
    await c.query('COMMIT');
    return result;
  } catch (e) {
    try { await c.query('ROLLBACK'); } catch { }
    throw e;
  } finally {
    c.release();
  }
}

async function op(sql: string, params: unknown[] = []): Promise<OpResult> {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    const res = await c.query(sql, params);
    await c.query('COMMIT');
    return { rowCount: res.rowCount ?? 0, err: null };
  } catch (e: any) {
    try { await c.query('ROLLBACK'); } catch { }
    return { rowCount: 0, err: e?.code ?? String(e?.message ?? e) };
  } finally {
    c.release();
  }
}

interface Ids {
  serviceAreaId: string;
  vehicleTypeId: string;
  pricingRuleId: string;
  pricingRuleVersion: number;
  customer1UserId: string;
  customer2UserId: string;
  driver1UserId: string;
  driver2UserId: string;
  vehicle1Id: string;
  vehicle2Id: string;
}

async function ensureReferenceData(): Promise<Ids> {
  return withTxn(async (c) => {
    await c.query(`INSERT INTO currencies (code, minor_unit_digits, is_active) VALUES ('YER', 2, true) ON CONFLICT (code) DO NOTHING`);

    let sa = (await c.query(`SELECT id FROM service_areas WHERE code = $1`, ['SANAA'])).rows[0];
    if (!sa) {
      sa = (await c.query(
        `INSERT INTO service_areas (id, code, name_ar, name_en, boundary, timezone, currency_code)
         VALUES ($1,'SANAA','صنعاء','Sanaa', ST_GeogFromText('SRID=4326;MULTIPOLYGON(((44.10 15.27, 44.29 15.27, 44.29 15.46, 44.10 15.46, 44.10 15.27)))'), 'Asia/Aden', 'YER') RETURNING id`,
        [SANAA_ID]
      )).rows[0];
    }
    const serviceAreaId = sa.id;

    await c.query(
      `INSERT INTO dispatch_settings (service_area_id, search_radius_m, max_candidates, offer_batch_size, offer_ttl_seconds, search_timeout_seconds, location_max_age_seconds, start_code_ttl_minutes, start_code_max_attempts)
       VALUES ($1, 3000, 5, 1, 20, 120, 30, 120, 5) ON CONFLICT (service_area_id) DO NOTHING`,
      [serviceAreaId]
    );

    let vt = (await c.query(`SELECT id FROM vehicle_types WHERE code = $1`, ['STANDARD'])).rows[0];
    if (!vt) {
      vt = (await c.query(
        `INSERT INTO vehicle_types (id, code, name_ar, name_en, capacity, sort_order) VALUES ($1,'STANDARD','سيارة عادية','Standard car', 4, 1) RETURNING id`,
        [STANDARD_ID]
      )).rows[0];
    }
    const vehicleTypeId = vt.id;

    const ensureUser = async (phone: string) => {
      const r = await c.query(`INSERT INTO users (phone_e164, status) VALUES ($1, 'ACTIVE') ON CONFLICT (phone_e164) DO UPDATE SET status = 'ACTIVE', deleted_at = NULL RETURNING id`, [phone]);
      return r.rows[0].id;
    };
    const customer1UserId = await ensureUser('+967700000001');
    const customer2UserId = await ensureUser('+967700000002');
    const driver1UserId = await ensureUser('+967700000003');
    const driver2UserId = await ensureUser('+967700000004');

    await c.query(`INSERT INTO customer_profiles (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`, [customer1UserId]);
    await c.query(`INSERT INTO customer_profiles (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`, [customer2UserId]);

    await c.query(
      `UPDATE rides SET status = 'CANCELLED', cancelled_at = now(), cancelled_by_role = 'SYSTEM', cancel_reason_code = 'cleanup', updated_at = now()
       WHERE (customer_id = ANY($1::uuid[]) OR driver_id = ANY($2::uuid[])) AND status IN ('SEARCHING', 'ASSIGNED')`,
      [[customer1UserId, customer2UserId], [driver1UserId, driver2UserId]]
    );
    await c.query(
      `DELETE FROM ride_offers ro USING rides r WHERE ro.ride_id = r.id AND (r.customer_id = ANY($1::uuid[]) OR r.driver_id = ANY($2::uuid[]))`,
      [[customer1UserId, customer2UserId], [driver1UserId, driver2UserId]]
    );

    let pr = (await c.query(
      `SELECT id, version FROM pricing_rules WHERE service_area_id = $1 AND vehicle_type_id = $2 AND status = 'ACTIVE'`,
      [serviceAreaId, vehicleTypeId]
    )).rows[0];
    if (!pr) {
      pr = (await c.query(
        `INSERT INTO pricing_rules (service_area_id, vehicle_type_id, version, mode, currency_code, base_fare, per_km, per_minute, minimum_fare, commission_bps, status, effective_from, published_by, created_by)
         VALUES ($1, $2, 1, 'DISTANCE_TIME', 'YER', 1000, 200, 20, 1500, 1500, 'ACTIVE', now(), $3, $3) RETURNING id, version`,
        [serviceAreaId, vehicleTypeId, customer1UserId]
      )).rows[0];
    }
    const pricingRuleId = pr.id;
    const pricingRuleVersion = pr.version;

    const ensureDriver = async (userId: string) => {
      await c.query(
        `INSERT INTO driver_profiles (user_id, full_name, service_area_id, verification_status, verification_reviewed_by, verification_reviewed_at, is_online, last_location, last_location_at)
         VALUES ($1, $2, $3, 'APPROVED', $1, now(), true, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, now())
         ON CONFLICT (user_id) DO UPDATE SET
           full_name = EXCLUDED.full_name,
           service_area_id = EXCLUDED.service_area_id,
           verification_status = 'APPROVED',
           verification_reviewed_by = EXCLUDED.verification_reviewed_by,
           verification_reviewed_at = now(),
           is_online = true,
           last_location = EXCLUDED.last_location,
           last_location_at = now()`,
        [userId, `سائق ${userId.slice(-4)}`, serviceAreaId, 44.20, 15.35]
      );
    };
    await ensureDriver(driver1UserId);
    await ensureDriver(driver2UserId);

    const ensureVehicle = async (driverId: string, plate: string) => {
      const existing = (await c.query(`SELECT id FROM vehicles WHERE plate_number = $1 AND is_active = true LIMIT 1`, [plate])).rows[0];
      if (existing) return existing.id;
      const r = await c.query(
        `INSERT INTO vehicles (driver_id, vehicle_type_id, plate_number, is_active) VALUES ($1, $2, $3, true) RETURNING id`,
        [driverId, vehicleTypeId, plate]
      );
      return r.rows[0].id;
    };
    const vehicle1Id = await ensureVehicle(driver1UserId, 'SANAA-101');
    const vehicle2Id = await ensureVehicle(driver2UserId, 'SANAA-102');

    return {
      serviceAreaId,
      vehicleTypeId,
      pricingRuleId,
      pricingRuleVersion,
      customer1UserId,
      customer2UserId,
      driver1UserId,
      driver2UserId,
      vehicle1Id,
      vehicle2Id,
    };
  });
}

const insertRideSql = `
  INSERT INTO rides
    (customer_id, service_area_id, vehicle_type_id, status, pickup, destination, pickup_address, destination_address,
     currency_code, pricing_rule_id, pricing_rule_version, price_breakdown, quoted_total,
     estimated_distance_m, estimated_duration_s, search_expires_at)
  VALUES
    ($1, $2, $3, 'SEARCHING',
     ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
     ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography,
     $8, $9, 'YER', $10, $11, $12::jsonb, $13, $14, $15, now() + interval '10 minutes')
  RETURNING id
`;

const cleanupRideSql = `
  UPDATE rides
  SET status = 'CANCELLED', cancelled_at = now(), cancelled_by_role = 'SYSTEM', cancel_reason_code = 'cleanup', updated_at = now()
  WHERE id = ANY($1::uuid[]) AND status IN ('SEARCHING', 'ASSIGNED')
`;

async function createRide(c: PoolClient, customerUserId: string, serviceAreaId: string, vehicleTypeId: string, pricingRuleId: string, pricingRuleVersion: number): Promise<string> {
  const r = await c.query(insertRideSql, [
    customerUserId, serviceAreaId, vehicleTypeId,
    44.20, 15.35, 44.25, 15.40,
    'موقع الاستلام', 'الوجهة',
    pricingRuleId, pricingRuleVersion,
    JSON.stringify({ base_fare: 1000, per_km: 200, per_minute: 20, distance_km: 5, duration_min: 10 }),
    2200, 5000, 600,
  ]);
  return r.rows[0].id;
}

type Scenario = { name: string; pass: boolean; detail: string };

async function runScenario(label: string, fn: (ids: Ids) => Promise<Scenario>, ids: Ids): Promise<Scenario> {
  try {
    return await fn(ids);
  } catch (e: any) {
    return { name: label, pass: false, detail: `استثناء غير متوقع: ${e?.message ?? e}` };
  }
}

async function scenario1(ids: Ids): Promise<Scenario> {
  const name = '1. سائقان يقبلان نفس العرض في وقت واحد (double accept نفس الرحلة)';
  const rideId = await withTxn(async (c) => {
    const id = await createRide(c, ids.customer1UserId, ids.serviceAreaId, ids.vehicleTypeId, ids.pricingRuleId, ids.pricingRuleVersion);
    await c.query(`INSERT INTO ride_offers (ride_id, driver_id, status, round_no, expires_at) VALUES ($1, $2, 'PENDING', 1, now() + interval '5 minutes')`, [id, ids.driver1UserId]);
    await c.query(`INSERT INTO ride_offers (ride_id, driver_id, status, round_no, expires_at) VALUES ($1, $2, 'PENDING', 1, now() + interval '5 minutes')`, [id, ids.driver2UserId]);
    return id;
  });

  const acceptSql = `UPDATE rides SET status = 'ASSIGNED', driver_id = $1, vehicle_id = $2, assigned_at = now(), start_code_nonce = decode($4,'hex'), start_code_expires_at = now() + interval '10 minutes' WHERE id = $3 AND status = 'SEARCHING' AND driver_id IS NULL RETURNING *`;
  const [r1, r2] = await Promise.all([
    op(acceptSql, [ids.driver1UserId, ids.vehicle1Id, rideId, 'deadbeef']),
    op(acceptSql, [ids.driver2UserId, ids.vehicle2Id, rideId, 'deadbeef']),
  ]);

  const sum = r1.rowCount + r2.rowCount;
  const pass = sum === 1;
  await withTxn(async (c) => { await c.query(cleanupRideSql, [[rideId]]); });
  return {
    name, pass,
    detail: `السائق1 rowCount=${r1.rowCount} err=${r1.err}; السائق2 rowCount=${r2.rowCount} err=${r2.err}; المجموع=${sum} (المتوقع 1)`,
  };
}

async function scenario2(ids: Ids): Promise<Scenario> {
  const name = '2. سائق يقبل عرضين لرحلتين متعارضتين (رحلة واحدة نشطة لكل سائق)';
  const { rideAId, rideBId } = await withTxn(async (c) => {
    const rideAId = await createRide(c, ids.customer1UserId, ids.serviceAreaId, ids.vehicleTypeId, ids.pricingRuleId, ids.pricingRuleVersion);
    const rideBId = await createRide(c, ids.customer2UserId, ids.serviceAreaId, ids.vehicleTypeId, ids.pricingRuleId, ids.pricingRuleVersion);
    await c.query(`INSERT INTO ride_offers (ride_id, driver_id, status, round_no, expires_at) VALUES ($1, $2, 'PENDING', 1, now() + interval '5 minutes')`, [rideAId, ids.driver1UserId]);
    await c.query(`INSERT INTO ride_offers (ride_id, driver_id, status, round_no, expires_at) VALUES ($1, $2, 'PENDING', 1, now() + interval '5 minutes')`, [rideBId, ids.driver1UserId]);
    return { rideAId, rideBId };
  });

  const acceptSql = `UPDATE rides SET status = 'ASSIGNED', driver_id = $1, vehicle_id = $2, assigned_at = now(), start_code_nonce = decode($4,'hex'), start_code_expires_at = now() + interval '10 minutes' WHERE id = $3 AND status = 'SEARCHING' AND driver_id IS NULL RETURNING *`;
  const [rA, rB] = await Promise.all([
    op(acceptSql, [ids.driver1UserId, ids.vehicle1Id, rideAId, 'deadbeef']),
    op(acceptSql, [ids.driver1UserId, ids.vehicle1Id, rideBId, 'deadbeef']),
  ]);

  const sum = rA.rowCount + rB.rowCount;
  const pass = sum === 1;
  await withTxn(async (c) => { await c.query(cleanupRideSql, [[rideAId, rideBId]]); });
  return {
    name, pass,
    detail: `الرحلةA rowCount=${rA.rowCount} err=${rA.err}; الرحلةB rowCount=${rB.rowCount} err=${rB.err}; المجموع=${sum} (المتوقع 1)`,
  };
}

async function scenario3(ids: Ids): Promise<Scenario> {
  const name = '3. إعادة POST /rides بمفتاح استidem-key مكرر (جدول idempotency_keys)';
  const [r1, r2] = await Promise.all([
    op(`INSERT INTO idempotency_keys (user_id, scope, idempotency_key, request_hash, expires_at) VALUES ($1, 'POST /rides', 'idem-ride-1', $2, now() + interval '1 hour')`, [ids.customer1UserId, 'hash-1']),
    op(`INSERT INTO idempotency_keys (user_id, scope, idempotency_key, request_hash, expires_at) VALUES ($1, 'POST /rides', 'idem-ride-1', $2, now() + interval '1 hour')`, [ids.customer1UserId, 'hash-1']),
  ]);
  const sum = r1.rowCount + r2.rowCount;
  const pass = sum === 1 && (r1.err === '23505' || r2.err === '23505');
  await pool.query(`DELETE FROM idempotency_keys WHERE idempotency_key = 'idem-ride-1'`);
  return {
    name, pass,
    detail: `العملية1 rowCount=${r1.rowCount} err=${r1.err}; العملية2 rowCount=${r2.rowCount} err=${r2.err}; المجموع=${sum} (المتوقع 1 + انتهاك فريد 23505)`,
  };
}

async function scenario4(ids: Ids): Promise<Scenario> {
  const name = '4. حدث/إشعار مكرر (notification dedupe)';
  const [r1, r2] = await Promise.all([
    op(`INSERT INTO notifications (user_id, kind, title, body, data, dedupe_key) VALUES ($1, 'ride_offer', 'عرض جديد', 'نص تجريبي', '{}'::jsonb, 'notif-1')`, [ids.customer1UserId]),
    op(`INSERT INTO notifications (user_id, kind, title, body, data, dedupe_key) VALUES ($1, 'ride_offer', 'عرض جديد', 'نص تجريبي', '{}'::jsonb, 'notif-1')`, [ids.customer1UserId]),
  ]);
  const sum = r1.rowCount + r2.rowCount;
  const pass = sum === 1 && (r1.err === '23505' || r2.err === '23505');
  await pool.query(`DELETE FROM notifications WHERE dedupe_key = 'notif-1'`);
  return {
    name, pass,
    detail: `الإشعار1 rowCount=${r1.rowCount} err=${r1.err}; الإشعار2 rowCount=${r2.rowCount} err=${r2.err}; المجموع=${sum} (المتوقع 1 + انتهاك فريد 23505)`,
  };
}

async function scenario5(ids: Ids): Promise<Scenario> {
  const name = '5. إعادة تنفيذ عملية مالية بمفتاح استidem-key مكرر (driver_ledger_entries)';
  let rideId: string;
  const ledgerKey = 'pay-1-' + Date.now();
  rideId = await withTxn(async (c) => {
    return createRide(c, ids.customer1UserId, ids.serviceAreaId, ids.vehicleTypeId, ids.pricingRuleId, ids.pricingRuleVersion);
  });
  const [r1, r2] = await Promise.all([
    op(`INSERT INTO driver_ledger_entries (driver_id, ride_id, entry_type, amount, currency_code, idempotency_key, memo) VALUES ($1, $2, 'EARNING', 5000.00, 'YER', $3, 'scenario-5-cleanup')`, [ids.driver1UserId, rideId, ledgerKey]),
    op(`INSERT INTO driver_ledger_entries (driver_id, ride_id, entry_type, amount, currency_code, idempotency_key, memo) VALUES ($1, $2, 'EARNING', 5000.00, 'YER', $3, 'scenario-5-cleanup')`, [ids.driver1UserId, rideId, ledgerKey]),
  ]);
  const sum = r1.rowCount + r2.rowCount;
  const pass = sum === 1 && (r1.err === '23505' || r2.err === '23505');
  await withTxn(async (c) => { await c.query(cleanupRideSql, [[rideId]]); });
  return {
    name, pass,
    detail: `القيد1 rowCount=${r1.rowCount} err=${r1.err}; القيد2 rowCount=${r2.rowCount} err=${r2.err}; المجموع=${sum} (المتوقع 1 + انتهاك فريد 23505)`,
  };
}

async function scenario6(ids: Ids): Promise<Scenario> {
  const name = '6. انتهاء صلاحية العرض أثناء محاولة القبول';
  const { rideId, offerId } = await withTxn(async (c) => {
    const id = await createRide(c, ids.customer1UserId, ids.serviceAreaId, ids.vehicleTypeId, ids.pricingRuleId, ids.pricingRuleVersion);
    // offered_at في الماضي و expires_at في الماضي ولكن expires_at > offered_at (يتيحه الـ check constraint).
    const r = await c.query(
      `INSERT INTO ride_offers (ride_id, driver_id, status, round_no, offered_at, expires_at)
       VALUES ($1, $2, 'PENDING', 1, now() - interval '1 hour', now() - interval '1 minute') RETURNING id`,
      [id, ids.driver1UserId]
    );
    return { rideId: id, offerId: r.rows[0].id };
  });

  const res = await op(`UPDATE ride_offers SET status = 'ACCEPTED', responded_at = now() WHERE id = $1 AND status = 'PENDING' AND expires_at > now() RETURNING *`, [offerId]);
  const pass = res.rowCount === 0;
  await withTxn(async (c) => {
    await c.query(`DELETE FROM ride_offers WHERE id = $1`, [offerId]);
    await c.query(cleanupRideSql, [[rideId]]);
  });
  return {
    name, pass,
    detail: `الصفوف المحدثة=${res.rowCount} err=${res.err} (المتوقع 0 لأن العرض منتهٍ)`,
  };
}

async function main(): Promise<void> {
  const results: Scenario[] = [];
  try {
    const ids = await ensureReferenceData();
    console.log('البيانات المرجعية جاهزة:', JSON.stringify({
      service_area: ids.serviceAreaId,
      vehicle_type: ids.vehicleTypeId,
      pricing_rule: ids.pricingRuleId,
      customer1: ids.customer1UserId,
      customer2: ids.customer2UserId,
      driver1: ids.driver1UserId,
      driver2: ids.driver2UserId,
      vehicle1: ids.vehicle1Id,
      vehicle2: ids.vehicle2Id,
    }));

    results.push(await runScenario('1. سائقان يقبلان نفس العرض في وقت واحد (double accept نفس الرحلة)', scenario1, ids));
    results.push(await runScenario('2. سائق يقبل عرضين لرحلتين متعارضتين (رحلة واحدة نشطة لكل سائق)', scenario2, ids));
    results.push(await runScenario('3. إعادة POST /rides بمفتاح استidem-key مكرر (جدول idempotency_keys)', scenario3, ids));
    results.push(await runScenario('4. حدث/إشعار مكرر (notification dedupe)', scenario4, ids));
    results.push(await runScenario('5. إعادة تنفيذ عملية مالية بمفتاح استidem-key مكرر (driver_ledger_entries)', scenario5, ids));
    results.push(await runScenario('6. انتهاء صلاحية العرض أثناء محاولة القبول', scenario6, ids));
  } catch (e: any) {
    console.error('خطأ غير متوقع:', e?.message ?? e);
  } finally {
    await pool.end();
  }

  console.log('\n=== نتائج سيناريوهات تزامن منع تعارض إسناد الرحلات (المتطلب #9) ===');
  let passed = 0;
  for (const s of results) {
    passed += s.pass ? 1 : 0;
    console.log(`${s.pass ? 'PASS' : 'FAIL'} | ${s.name}`);
    console.log(`   ${s.detail}`);
  }
  console.log(`\nالملخص: نجح ${passed} من ${results.length} سيناريو.`);
}

main();
