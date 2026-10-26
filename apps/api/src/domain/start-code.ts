/**
 * Trip start code.
 *
 * The code is *derived*, not stored: code = HMAC-SHA256(secret, ride_id || nonce)
 * truncated to N decimal digits. The database keeps only a random per-ride
 * `start_code_nonce`, an expiry and an attempt counter, so a database leak
 * alone does not reveal any code, and the customer app can be shown the code
 * again after a reopen (the API recomputes it for the owning customer only).
 *
 * The driver never receives the code; the driver types what the customer
 * tells them. Verification is constant-time and attempt-limited.
 *
 * The caller MUST increment `start_code_attempts` atomically in SQL
 * (UPDATE ... SET attempts = attempts + 1 ... RETURNING attempts) *before*
 * calling `verifyStartCode`, so parallel guesses cannot exceed the limit.
 */

import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

export const START_CODE_DIGITS = 4;

export function newStartCodeNonce(): Buffer {
  return randomBytes(16);
}

export function deriveStartCode(secret: Buffer | string, ride_id: string, nonce: Buffer, digits = START_CODE_DIGITS): string {
  if (digits < 4 || digits > 8) throw new RangeError('digits must be between 4 and 8');
  const mac = createHmac('sha256', secret).update(ride_id).update('\u0000').update(nonce).digest();
  const n = mac.readUInt32BE(0);
  const mod = 10 ** digits;
  return String(n % mod).padStart(digits, '0');
}

export type StartCodeFailure = 'MALFORMED' | 'EXPIRED' | 'LOCKED' | 'MISMATCH';

export type StartCodeResult = { ok: true } | { ok: false; reason: StartCodeFailure };

export interface VerifyStartCodeInput {
  secret: Buffer | string;
  ride_id: string;
  nonce: Buffer;
  submitted: string;
  expires_at: Date;
  now: Date;
  /** Attempts used *including* the current one (already incremented in SQL). */
  attemptsUsed: number;
  max_attempts: number;
  digits?: number;
}

export function verifyStartCode(input: VerifyStartCodeInput): StartCodeResult {
  const digits = input.digits ?? START_CODE_DIGITS;
  if (input.attemptsUsed > input.max_attempts) return { ok: false, reason: 'LOCKED' };
  if (input.now.getTime() >= input.expires_at.getTime()) return { ok: false, reason: 'EXPIRED' };
  if (!new RegExp(`^[0-9]{${digits}}$`).test(input.submitted)) return { ok: false, reason: 'MALFORMED' };

  const expected = Buffer.from(deriveStartCode(input.secret, input.ride_id, input.nonce, digits), 'utf8');
  const given = Buffer.from(input.submitted, 'utf8');
  const equal = expected.length === given.length && timingSafeEqual(expected, given);
  return equal ? { ok: true } : { ok: false, reason: 'MISMATCH' };
}
