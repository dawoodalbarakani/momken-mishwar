import { test } from 'node:test';
import assert from 'node:assert/strict';
import { LedgerError, balanceMinor, buildCashRideEntries, buildSettlementEntry } from './ledger';

const ride = { rideId: 'r-1', driverId: 'd-1', currency: 'XTS', grossMinor: 450, commissionMinor: 68, driverNetMinor: 382 };

test('cash ride posts earning and cash-collected; driver owes exactly the commission', () => {
  const entries = buildCashRideEntries(ride);
  assert.deepEqual(entries.map((e) => [e.entryType, e.amountMinor]), [['EARNING', 382], ['CASH_COLLECTED', -450]]);
  assert.equal(balanceMinor(entries, 'XTS'), -68);
  assert.deepEqual(entries.map((e) => e.idempotencyKey), ['ride:r-1:EARNING', 'ride:r-1:CASH_COLLECTED']);
});

test('replaying the same ride yields identical idempotency keys (DB unique key blocks the duplicate)', () => {
  const a = buildCashRideEntries(ride).map((e) => e.idempotencyKey);
  const b = buildCashRideEntries(ride).map((e) => e.idempotencyKey);
  assert.deepEqual(a, b);
});

test('amounts that do not balance are refused', () => {
  assert.throws(() => buildCashRideEntries({ ...ride, driverNetMinor: 383 }), (e: unknown) => e instanceof LedgerError && e.code === 'AMOUNTS_DO_NOT_BALANCE');
});

test('zero-amount legs are not posted', () => {
  const free = buildCashRideEntries({ ...ride, grossMinor: 0, commissionMinor: 0, driverNetMinor: 0 });
  assert.equal(free.length, 0);
});

test('driver handing cash to the platform clears the debt', () => {
  const entries = [
    ...buildCashRideEntries(ride),
    buildSettlementEntry({ driverId: 'd-1', payoutId: 'p-1', currency: 'XTS', amountMinor: 68, direction: 'DRIVER_TO_PLATFORM' }),
  ];
  assert.equal(balanceMinor(entries, 'XTS'), 0);
});

test('platform paying out an earned balance reduces what it owes', () => {
  const credit = { driverId: 'd-1', rideId: null, payoutId: null, entryType: 'ADJUSTMENT' as const, amountMinor: 1000, currency: 'XTS', idempotencyKey: 'adj:1' };
  const pay = buildSettlementEntry({ driverId: 'd-1', payoutId: 'p-2', currency: 'XTS', amountMinor: 400, direction: 'PLATFORM_TO_DRIVER' });
  assert.equal(balanceMinor([credit, pay], 'XTS'), 600);
  assert.equal(pay.idempotencyKey, 'payout:p-2:TO_DRIVER');
});

test('balances never mix currencies; zero settlements are refused', () => {
  const e = buildCashRideEntries(ride);
  assert.throws(() => balanceMinor(e, 'YER'), (err: unknown) => err instanceof LedgerError && err.code === 'MIXED_CURRENCY');
  assert.throws(() => buildSettlementEntry({ driverId: 'd', payoutId: 'p', currency: 'XTS', amountMinor: 0, direction: 'DRIVER_TO_PLATFORM' }), (err: unknown) => err instanceof LedgerError && err.code === 'INVALID_AMOUNT');
});
