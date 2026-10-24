import { test } from 'node:test';
import assert from 'node:assert/strict';
import { deriveStartCode, newStartCodeNonce, verifyStartCode } from './start-code';

const secret = 'test-secret-not-for-production';
const rideId = '11111111-1111-4111-8111-111111111111';
const nonce = Buffer.from('00112233445566778899aabbccddeeff', 'hex');
const now = new Date('2026-10-24T12:00:00Z');
const later = new Date('2026-10-24T12:10:00Z');
const base = { secret, rideId, nonce, now, expiresAt: later, maxAttempts: 5 };

test('code is deterministic, 4 digits, and depends on ride and nonce', () => {
  const c = deriveStartCode(secret, rideId, nonce);
  assert.match(c, /^[0-9]{4}$/);
  assert.equal(deriveStartCode(secret, rideId, nonce), c);
  const nonces = new Set(Array.from({ length: 50 }, () => deriveStartCode(secret, rideId, newStartCodeNonce())));
  assert.ok(nonces.size > 30, 'different nonces should yield varied codes');
  assert.notEqual(deriveStartCode('another-secret', rideId, nonce), c, 'a different secret must change the code');
});

test('correct code verifies', () => {
  const c = deriveStartCode(secret, rideId, nonce);
  assert.deepEqual(verifyStartCode({ ...base, submitted: c, attemptsUsed: 1 }), { ok: true });
});

test('wrong, malformed, expired and locked codes are rejected with distinct reasons', () => {
  const c = deriveStartCode(secret, rideId, nonce);
  const wrong = c === '0000' ? '0001' : '0000';
  assert.deepEqual(verifyStartCode({ ...base, submitted: wrong, attemptsUsed: 1 }), { ok: false, reason: 'MISMATCH' });
  assert.deepEqual(verifyStartCode({ ...base, submitted: '12a4', attemptsUsed: 1 }), { ok: false, reason: 'MALFORMED' });
  assert.deepEqual(verifyStartCode({ ...base, submitted: '123', attemptsUsed: 1 }), { ok: false, reason: 'MALFORMED' });
  assert.deepEqual(verifyStartCode({ ...base, submitted: c, attemptsUsed: 1, now: later }), { ok: false, reason: 'EXPIRED' });
  // Even the correct code is refused once the attempt budget is exhausted.
  assert.deepEqual(verifyStartCode({ ...base, submitted: c, attemptsUsed: 6 }), { ok: false, reason: 'LOCKED' });
  assert.deepEqual(verifyStartCode({ ...base, submitted: c, attemptsUsed: 5 }), { ok: true });
});

test('a code for a different ride does not verify', () => {
  const other = '22222222-2222-4222-8222-222222222222';
  const codeForOther = deriveStartCode(secret, other, nonce);
  const codeForThis = deriveStartCode(secret, rideId, nonce);
  assert.notEqual(codeForOther, codeForThis, 'fixture ids must yield different codes');
  assert.deepEqual(verifyStartCode({ ...base, submitted: codeForOther, attemptsUsed: 1 }), { ok: false, reason: 'MISMATCH' });
});
