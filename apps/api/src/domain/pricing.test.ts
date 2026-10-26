import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PricingError, PricingRule, computePrice } from './pricing.js';

// TEST FIXTURE ONLY. These numbers are NOT market data for Yemen.
const rule: PricingRule = {
  id: 'rule-1',
  version: 3,
  mode: 'DISTANCE_TIME',
  currency: 'XTS', // synthetic test currency
  baseFareMinor: 100,
  perKmMinor: 50,
  perMinuteMinor: 10,
  minimumFareMinor: 300,
  surcharges: [],
  commission_bps: 1500,
  roundingStepMinor: 1,
};

test('distance+time: base + distance + time, snapshot carries rule id/version', () => {
  // 5 km, 10 min -> 100 + 250 + 100 = 450
  const p = computePrice(rule, { distanceMeters: 5000, durationSeconds: 600 });
  assert.equal(p.totalMinor, 450);
  assert.deepEqual(p.lines.map((l) => l.code), ['BASE_FARE', 'DISTANCE', 'TIME']);
  assert.equal(p.ruleId, 'rule-1');
  assert.equal(p.ruleVersion, 3);
  assert.equal(p.estimated, true);
});

test('minimum fare adjustment is an explicit line', () => {
  // 1 km, 1 min -> 100 + 50 + 10 = 160 < 300
  const p = computePrice(rule, { distanceMeters: 1000, durationSeconds: 60 });
  assert.equal(p.totalMinor, 300);
  assert.deepEqual(p.lines.at(-1), { code: 'MINIMUM_FARE_ADJUSTMENT', amountMinor: 140 });
});

test('commission + driver net always equal the total (no lost minor unit)', () => {
  for (const [d, t] of [[1234, 77], [9999, 3601], [0, 0], [50_000, 4000]] as const) {
    const p = computePrice(rule, { distanceMeters: d, durationSeconds: t });
    assert.equal(p.commissionMinor + p.driverNetMinor, p.totalMinor);
  }
  const p = computePrice(rule, { distanceMeters: 5000, durationSeconds: 600 });
  assert.equal(p.commissionMinor, 68); // 450 * 15% = 67.5 -> 68 (half up)
  assert.equal(p.driverNetMinor, 382);
});

test('surcharges: flat and percent (no compounding), then percent discount with cap', () => {
  const r: PricingRule = {
    ...rule,
    surcharges: [
      { code: 'NIGHT', kind: 'PERCENT_BPS', value: 1000 }, // 10% of 450 = 45
      { code: 'SERVICE', kind: 'FLAT', value: 20 },
    ],
  };
  const noDiscount = computePrice(r, { distanceMeters: 5000, durationSeconds: 600 });
  assert.equal(noDiscount.totalMinor, 450 + 45 + 20);

  const discounted = computePrice(r, {
    distanceMeters: 5000,
    durationSeconds: 600,
    discount: { code: 'PROMO', kind: 'PERCENT_BPS', value: 5000, maxMinor: 100 }, // 50% = 257 -> capped 100
  });
  assert.equal(discounted.discountMinor, 100);
  assert.equal(discounted.totalMinor, 515 - 100);
});

test('discount can never push the total below zero', () => {
  const p = computePrice(rule, {
    distanceMeters: 1000,
    durationSeconds: 60,
    discount: { code: 'BIG', kind: 'FLAT', value: 10_000 },
  });
  assert.equal(p.totalMinor, 0);
  assert.equal(p.discountMinor, 300);
  assert.equal(p.commissionMinor, 0);
});

test('rounding to a step adds an explicit ROUNDING line', () => {
  const p = computePrice({ ...rule, roundingStepMinor: 50 }, { distanceMeters: 5000, durationSeconds: 600 }); // 450 -> 450
  assert.equal(p.totalMinor, 450);
  const q = computePrice({ ...rule, roundingStepMinor: 50 }, { distanceMeters: 5200, durationSeconds: 600 }); // 460 -> 450
  assert.equal(q.totalMinor, 450);
  assert.deepEqual(q.lines.at(-1), { code: 'ROUNDING', amountMinor: -10 });
});

test('fixed route requires a matched route and ignores distance/time', () => {
  const fixed: PricingRule = { ...rule, mode: 'FIXED_ROUTE' };
  assert.throws(() => computePrice(fixed, { distanceMeters: 1, durationSeconds: 1 }), (e: unknown) => e instanceof PricingError && e.code === 'FIXED_ROUTE_REQUIRED');
  const p = computePrice(fixed, { distanceMeters: 99_999, durationSeconds: 99_999, fixedRoute: { id: 'fr-1', fareMinor: 700 } });
  assert.equal(p.totalMinor, 700);
  assert.equal(p.fixedRouteId, 'fr-1');
});

test('manual fare needs an amount and an approver, and skips surcharges/discounts', () => {
  const manual: PricingRule = { ...rule, mode: 'MANUAL', surcharges: [{ code: 'X', kind: 'FLAT', value: 99 }] };
  assert.throws(() => computePrice(manual, { distanceMeters: 1, durationSeconds: 1 }), (e: unknown) => e instanceof PricingError && e.code === 'MANUAL_FARE_REQUIRED');
  assert.throws(() => computePrice(manual, { distanceMeters: 1, durationSeconds: 1, manualFareMinor: 500 }), (e: unknown) => e instanceof PricingError && e.code === 'MANUAL_APPROVER_REQUIRED');
  const p = computePrice(manual, { distanceMeters: 1, durationSeconds: 1, manualFareMinor: 500, manualApprovedBy: 'staff-9' });
  assert.equal(p.totalMinor, 500);
  assert.equal(p.manualApprovedBy, 'staff-9');
  assert.deepEqual(p.lines, [{ code: 'MANUAL_FARE', amountMinor: 500 }]);
});

test('invalid rules and inputs are rejected with typed errors', () => {
  assert.throws(() => computePrice({ ...rule, commission_bps: 10_001 }, { distanceMeters: 1, durationSeconds: 1 }), (e: unknown) => e instanceof PricingError && e.code === 'INVALID_RULE');
  assert.throws(() => computePrice({ ...rule, roundingStepMinor: 0 }, { distanceMeters: 1, durationSeconds: 1 }), (e: unknown) => e instanceof PricingError && e.code === 'INVALID_RULE');
  assert.throws(() => computePrice({ ...rule, baseFareMinor: 1.5 }, { distanceMeters: 1, durationSeconds: 1 }), (e: unknown) => e instanceof PricingError && e.code === 'INVALID_RULE');
  assert.throws(() => computePrice(rule, { distanceMeters: -1, durationSeconds: 1 }), (e: unknown) => e instanceof PricingError && e.code === 'INVALID_INPUT');
});

test('same rule + input is deterministic and does not mutate the rule', () => {
  const before = JSON.stringify(rule);
  const a = computePrice(rule, { distanceMeters: 4321, durationSeconds: 555 });
  const b = computePrice(rule, { distanceMeters: 4321, durationSeconds: 555 });
  assert.deepEqual(a, b);
  assert.equal(JSON.stringify(rule), before);
});
