/**
 * Money primitives for Mishwar Yemen.
 *
 * Amounts are integers in the currency's minor unit (no floats anywhere).
 * The database stores NUMERIC(18,2); the repository layer converts using the
 * currency's `minor_unit_digits` (see docs/database-design.md §Money).
 */

export type CurrencyCode = string;

export interface Money {
  readonly minor: number;
  readonly currency: CurrencyCode;
}

export class MoneyError extends Error {
  constructor(
    public readonly code:
      | 'NOT_SAFE_INTEGER'
      | 'NEGATIVE_NOT_ALLOWED'
      | 'CURRENCY_MISMATCH'
      | 'INVALID_RATIO',
    message: string,
  ) {
    super(message);
    this.name = 'MoneyError';
  }
}

export function assertMinor(value: number, label = 'amount'): void {
  if (!Number.isSafeInteger(value)) {
    throw new MoneyError('NOT_SAFE_INTEGER', `${label} must be a safe integer (minor units), got ${value}`);
  }
}

export function assertNonNegativeMinor(value: number, label = 'amount'): void {
  assertMinor(value, label);
  if (value < 0) {
    throw new MoneyError('NEGATIVE_NOT_ALLOWED', `${label} must be >= 0, got ${value}`);
  }
}

export function money(minor: number, currency: CurrencyCode): Money {
  assertMinor(minor);
  return { minor, currency };
}

export function assertSameCurrency(a: Money, b: Money): void {
  if (a.currency !== b.currency) {
    throw new MoneyError('CURRENCY_MISMATCH', `Currency mismatch: ${a.currency} vs ${b.currency}`);
  }
}

export function add(a: Money, b: Money): Money {
  assertSameCurrency(a, b);
  return money(a.minor + b.minor, a.currency);
}

export function sub(a: Money, b: Money): Money {
  assertSameCurrency(a, b);
  return money(a.minor - b.minor, a.currency);
}

/**
 * round_half_up(a * b / d) for non-negative integers, computed with BigInt so
 * the intermediate product can never lose precision.
 */
export function mulDivRound(a: number, b: number, d: number): number {
  assertNonNegativeMinor(a, 'a');
  assertNonNegativeMinor(b, 'b');
  if (!Number.isSafeInteger(d) || d <= 0) {
    throw new MoneyError('INVALID_RATIO', `divisor must be a positive safe integer, got ${d}`);
  }
  const bd = BigInt(d);
  const result = (BigInt(a) * BigInt(b) + bd / 2n) / bd;
  const asNumber = Number(result);
  assertMinor(asNumber, 'result');
  return asNumber;
}

/** Round `value` to the nearest multiple of `step` (half up). `step >= 1`. */
export function roundToStep(value: number, step: number): number {
  assertNonNegativeMinor(value, 'value');
  if (!Number.isSafeInteger(step) || step < 1) {
    throw new MoneyError('INVALID_RATIO', `rounding step must be an integer >= 1, got ${step}`);
  }
  return mulDivRound(value, 1, step) * step;
}
