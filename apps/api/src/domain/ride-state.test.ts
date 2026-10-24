import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Actor, RideSnapshot, RideTransitionError, transition } from './ride-state';

const customer: Actor = { role: 'CUSTOMER', userId: 'cust-1' };
const driver: Actor = { role: 'DRIVER', userId: 'drv-1' };
const otherDriver: Actor = { role: 'DRIVER', userId: 'drv-2' };
const otherCustomer: Actor = { role: 'CUSTOMER', userId: 'cust-2' };
const system: Actor = { role: 'SYSTEM' };
const staff: Actor = { role: 'STAFF', userId: 'staff-1' };

const ride = (status: RideSnapshot['status'], driverId: string | null = 'drv-1'): RideSnapshot => ({
  status,
  customerId: 'cust-1',
  driverId,
});

const code = (e: unknown) => (e instanceof RideTransitionError ? e.code : 'NOT_A_RIDE_ERROR');
const throwsWith = (fn: () => unknown, expected: string) =>
  assert.throws(fn, (e: unknown) => code(e) === expected, `expected ${expected}`);

test('happy path from search to completion', () => {
  assert.equal(transition(ride('SEARCHING', null), 'DRIVER_ASSIGNED', driver, { assignedDriverId: 'drv-1' }).to, 'ASSIGNED');
  assert.equal(transition(ride('ASSIGNED'), 'DRIVER_EN_ROUTE', driver).to, 'ARRIVING');
  assert.equal(transition(ride('ARRIVING'), 'DRIVER_ARRIVED', driver).to, 'ARRIVED');
  assert.equal(transition(ride('ARRIVED'), 'TRIP_STARTED', driver, { startCodeVerified: true }).to, 'IN_PROGRESS');
  assert.equal(transition(ride('IN_PROGRESS'), 'TRIP_COMPLETED', driver).to, 'COMPLETED');
});

test('trip cannot start without a verified start code', () => {
  throwsWith(() => transition(ride('ARRIVED'), 'TRIP_STARTED', driver), 'START_CODE_NOT_VERIFIED');
  throwsWith(() => transition(ride('ARRIVED'), 'TRIP_STARTED', driver, { startCodeVerified: false }), 'START_CODE_NOT_VERIFIED');
});

test('only the assigned driver can advance or complete the trip', () => {
  throwsWith(() => transition(ride('ASSIGNED'), 'DRIVER_EN_ROUTE', otherDriver), 'FORBIDDEN_ACTOR');
  throwsWith(() => transition(ride('IN_PROGRESS'), 'TRIP_COMPLETED', otherDriver), 'FORBIDDEN_ACTOR');
  throwsWith(() => transition(ride('IN_PROGRESS'), 'TRIP_COMPLETED', customer), 'FORBIDDEN_ACTOR');
  throwsWith(() => transition(ride('IN_PROGRESS'), 'TRIP_COMPLETED', staff), 'FORBIDDEN_ACTOR');
});

test('steps cannot be skipped or replayed', () => {
  throwsWith(() => transition(ride('ASSIGNED'), 'DRIVER_ARRIVED', driver), 'INVALID_TRANSITION');
  throwsWith(() => transition(ride('ARRIVING'), 'TRIP_STARTED', driver, { startCodeVerified: true }), 'INVALID_TRANSITION');
  throwsWith(() => transition(ride('ASSIGNED'), 'TRIP_COMPLETED', driver), 'INVALID_TRANSITION');
  throwsWith(() => transition(ride('ARRIVING'), 'DRIVER_EN_ROUTE', driver), 'INVALID_TRANSITION');
});

test('assignment requires SEARCHING and a driver; a second assignment is rejected', () => {
  throwsWith(() => transition(ride('ASSIGNED'), 'DRIVER_ASSIGNED', system, { assignedDriverId: 'drv-2' }), 'INVALID_TRANSITION');
  throwsWith(() => transition(ride('SEARCHING', null), 'DRIVER_ASSIGNED', system), 'DRIVER_REQUIRED');
  throwsWith(() => transition(ride('SEARCHING', null), 'DRIVER_ASSIGNED', customer, { assignedDriverId: 'drv-1' }), 'FORBIDDEN_ACTOR');
  throwsWith(() => transition(ride('SEARCHING', null), 'DRIVER_ASSIGNED', otherDriver, { assignedDriverId: 'drv-1' }), 'FORBIDDEN_ACTOR');
});

test('search expiry is a system-only event', () => {
  assert.equal(transition(ride('SEARCHING', null), 'SEARCH_EXPIRED', system).to, 'NO_DRIVER_FOUND');
  throwsWith(() => transition(ride('SEARCHING', null), 'SEARCH_EXPIRED', customer), 'FORBIDDEN_ACTOR');
  throwsWith(() => transition(ride('ASSIGNED'), 'SEARCH_EXPIRED', system), 'INVALID_TRANSITION');
});

test('cancellation records who cancelled and requires a reason', () => {
  const byCustomer = transition(ride('ASSIGNED'), 'CANCEL', customer, { cancelReasonCode: 'CHANGED_MIND' });
  assert.deepEqual(byCustomer, { to: 'CANCELLED', cancelledBy: 'CUSTOMER', cancelReasonCode: 'CHANGED_MIND' });
  assert.equal(transition(ride('ARRIVING'), 'CANCEL', driver, { cancelReasonCode: 'VEHICLE_ISSUE' }).cancelledBy, 'DRIVER');
  assert.equal(transition(ride('SEARCHING', null), 'CANCEL', customer, { cancelReasonCode: 'X' }).to, 'CANCELLED');
  throwsWith(() => transition(ride('ASSIGNED'), 'CANCEL', customer), 'REASON_REQUIRED');
});

test('strangers cannot cancel someone else\'s ride', () => {
  throwsWith(() => transition(ride('ASSIGNED'), 'CANCEL', otherCustomer, { cancelReasonCode: 'X' }), 'FORBIDDEN_ACTOR');
  throwsWith(() => transition(ride('ASSIGNED'), 'CANCEL', otherDriver, { cancelReasonCode: 'X' }), 'FORBIDDEN_ACTOR');
  throwsWith(() => transition(ride('SEARCHING', null), 'CANCEL', driver, { cancelReasonCode: 'X' }), 'FORBIDDEN_ACTOR');
});

test('a trip in progress can only be cancelled by staff', () => {
  throwsWith(() => transition(ride('IN_PROGRESS'), 'CANCEL', customer, { cancelReasonCode: 'X' }), 'FORBIDDEN_ACTOR');
  throwsWith(() => transition(ride('IN_PROGRESS'), 'CANCEL', driver, { cancelReasonCode: 'X' }), 'FORBIDDEN_ACTOR');
  assert.equal(transition(ride('IN_PROGRESS'), 'CANCEL', staff, { cancelReasonCode: 'SAFETY' }).cancelledBy, 'STAFF');
});

test('terminal states accept nothing', () => {
  for (const s of ['COMPLETED', 'CANCELLED', 'NO_DRIVER_FOUND'] as const) {
    throwsWith(() => transition(ride(s), 'CANCEL', staff, { cancelReasonCode: 'X' }), 'INVALID_TRANSITION');
    throwsWith(() => transition(ride(s), 'TRIP_COMPLETED', driver), 'INVALID_TRANSITION');
  }
});
