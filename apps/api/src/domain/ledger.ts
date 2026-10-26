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
  driver_id: string;
  ride_id: string | null;
  payoutId: string | null;
  entry_type: LedgerEntryType;
  /** Signed, minor units, never zero. */
  amountMinor: number;
  currency: CurrencyCode;
  idempotency_key: string;
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
  ride_id: string;
  driver_id: string;
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
  const base = { driver_id: input.driver_id, ride_id: input.ride_id, payoutId: null, currency: input.currency };
  // Zero-amount entries are not posted (DB CHECK amount <> 0).
  if (input.driverNetMinor !== 0) {
    entries.push({ ...base, entry_type: 'EARNING', amountMinor: input.driverNetMinor, idempotency_key: `ride:${input.ride_id}:EARNING` });
  }
  if (input.grossMinor !== 0) {
    entries.push({ ...base, entry_type: 'CASH_COLLECTED', amountMinor: -input.grossMinor, idempotency_key: `ride:${input.ride_id}:CASH_COLLECTED` });
  }
  return entries;
}

export interface SettlementInput {
  driver_id: string;
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
    driver_id: input.driver_id,
    ride_id: null,
    payoutId: input.payoutId,
    entry_type: toPlatform ? 'SETTLEMENT_FROM_DRIVER' : 'SETTLEMENT_TO_DRIVER',
    // Driver pays platform -> driver's debt shrinks (+). Platform pays driver -> credit shrinks (-).
    amountMinor: toPlatform ? input.amountMinor : -input.amountMinor,
    currency: input.currency,
    idempotency_key: `payout:${input.payoutId}:${toPlatform ? 'FROM_DRIVER' : 'TO_DRIVER'}`,
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
