/**
 * Driver ledger (pure entry builders).
 *
 * Sign convention (per driver, per currency):
 *   amount > 0  -> the platform owes the driver
 *   amount < 0  -> the driver owes the platform
 *   balance     = SUM(amount)
 *
 * A completed CASH trip with gross fare F, commission C, driver net N (F = C + N):
 *   EARNING        +N   the driver earned N for the trip
 *   CASH_COLLECTED -F   the driver physically holds F that belongs to the platform flow
 *   balance change = N - F = -C  -> the driver owes the platform the commission.
 *
 * Settlements and corrections are further entries; nothing is ever updated or
 * deleted (a DB trigger enforces append-only). Every entry carries a unique
 * idempotency key so a replayed request cannot post twice.
 */

import { CurrencyCode, assertNonNegativeMinor } from './money.js';

export type LedgerEntryType =
  | 'EARNING'
  | 'CASH_COLLECTED'
  | 'SETTLEMENT_FROM_DRIVER'
  | 'SETTLEMENT_TO_DRIVER'
  | 'ADJUSTMENT'
  | 'REVERSAL';

export interface LedgerEntryDraft {
  driverId: string;
  rideId: string | null;
  payoutId: string | null;
  entryType: LedgerEntryType;
  /** Signed, minor units, never zero. */
  amountMinor: number;
  currency: CurrencyCode;
  idempotencyKey: string;
  memo?: string;
}

export class LedgerError extends Error {
  constructor(
    public readonly code: 'AMOUNTS_DO_NOT_BALANCE' | 'INVALID_AMOUNT' | 'MIXED_CURRENCY',
    message: string,
  ) {
    super(message);
    this.name = 'LedgerError';
  }
}

export interface CashRideSettlementInput {
  rideId: string;
  driverId: string;
  currency: CurrencyCode;
  /** Values come from the ride's stored price snapshot, never recomputed here. */
  grossMinor: number;
  commissionMinor: number;
  driverNetMinor: number;
}

export function buildCashRideEntries(input: CashRideSettlementInput): LedgerEntryDraft[] {
  assertNonNegativeMinor(input.grossMinor, 'grossMinor');
  assertNonNegativeMinor(input.commissionMinor, 'commissionMinor');
  assertNonNegativeMinor(input.driverNetMinor, 'driverNetMinor');
  if (input.commissionMinor + input.driverNetMinor !== input.grossMinor) {
    throw new LedgerError(
      'AMOUNTS_DO_NOT_BALANCE',
      `commission (${input.commissionMinor}) + driver net (${input.driverNetMinor}) != gross (${input.grossMinor})`,
    );
  }

  const entries: LedgerEntryDraft[] = [];
  const base = { driverId: input.driverId, rideId: input.rideId, payoutId: null, currency: input.currency };
  // Zero-amount entries are not posted (DB CHECK amount <> 0).
  if (input.driverNetMinor !== 0) {
    entries.push({ ...base, entryType: 'EARNING', amountMinor: input.driverNetMinor, idempotencyKey: `ride:${input.rideId}:EARNING` });
  }
  if (input.grossMinor !== 0) {
    entries.push({ ...base, entryType: 'CASH_COLLECTED', amountMinor: -input.grossMinor, idempotencyKey: `ride:${input.rideId}:CASH_COLLECTED` });
  }
  return entries;
}

export interface SettlementInput {
  driverId: string;
  payoutId: string;
  currency: CurrencyCode;
  amountMinor: number;
  /** DRIVER_TO_PLATFORM: driver hands cash over. PLATFORM_TO_DRIVER: platform pays the driver. */
  direction: 'DRIVER_TO_PLATFORM' | 'PLATFORM_TO_DRIVER';
}

export function buildSettlementEntry(input: SettlementInput): LedgerEntryDraft {
  assertNonNegativeMinor(input.amountMinor, 'amountMinor');
  if (input.amountMinor === 0) throw new LedgerError('INVALID_AMOUNT', 'settlement amount must be > 0');
  const toPlatform = input.direction === 'DRIVER_TO_PLATFORM';
  return {
    driverId: input.driverId,
    rideId: null,
    payoutId: input.payoutId,
    entryType: toPlatform ? 'SETTLEMENT_FROM_DRIVER' : 'SETTLEMENT_TO_DRIVER',
    // Driver pays platform -> driver's debt shrinks (+). Platform pays driver -> credit shrinks (-).
    amountMinor: toPlatform ? input.amountMinor : -input.amountMinor,
    currency: input.currency,
    idempotencyKey: `payout:${input.payoutId}:${toPlatform ? 'FROM_DRIVER' : 'TO_DRIVER'}`,
  };
}

export function balanceMinor(entries: readonly Pick<LedgerEntryDraft, 'amountMinor' | 'currency'>[], currency: CurrencyCode): number {
  let sum = 0;
  for (const e of entries) {
    if (e.currency !== currency) {
      throw new LedgerError('MIXED_CURRENCY', `entry currency ${e.currency} != ${currency}`);
    }
    sum += e.amountMinor;
  }
  return sum;
}
