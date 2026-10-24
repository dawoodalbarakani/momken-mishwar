import { test } from 'node:test';
import assert from 'node:assert/strict';
import { MoneyError, add, mulDivRound, money, roundToStep, sub } from './money';

test('mulDivRound rounds half up and survives large products', () => {
  assert.equal(mulDivRound(5, 1, 2), 3); // 2.5 -> 3
  assert.equal(mulDivRound(4, 1, 3), 1); // 1.33 -> 1
  assert.equal(mulDivRound(5, 1, 3), 2); // 1.67 -> 2
  // 9e12 * 10000 exceeds 2^53 as a plain product; BigInt keeps it exact.
  assert.equal(mulDivRound(9_000_000_000_000, 10_000, 10_000), 9_000_000_000_000);
});

test('roundToStep rounds to nearest multiple, half up', () => {
  assert.equal(roundToStep(474, 10), 470);
  assert.equal(roundToStep(475, 10), 480);
  assert.equal(roundToStep(475, 1), 475);
});

test('rejects floats, negatives and bad divisors', () => {
  assert.throws(() => money(1.5, 'YER'), (e: unknown) => e instanceof MoneyError && e.code === 'NOT_SAFE_INTEGER');
  assert.throws(() => mulDivRound(-1, 1, 1), (e: unknown) => e instanceof MoneyError && e.code === 'NEGATIVE_NOT_ALLOWED');
  assert.throws(() => mulDivRound(1, 1, 0), (e: unknown) => e instanceof MoneyError && e.code === 'INVALID_RATIO');
  assert.throws(() => roundToStep(10, 0), (e: unknown) => e instanceof MoneyError);
});

test('add/sub refuse to mix currencies', () => {
  assert.deepEqual(add(money(5, 'YER'), money(7, 'YER')), { minor: 12, currency: 'YER' });
  assert.deepEqual(sub(money(5, 'YER'), money(7, 'YER')), { minor: -2, currency: 'YER' });
  assert.throws(() => add(money(1, 'YER'), money(1, 'USD')), (e: unknown) => e instanceof MoneyError && e.code === 'CURRENCY_MISMATCH');
});
