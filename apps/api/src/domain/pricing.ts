/**
 * Pricing Engine (pure, no I/O).
 *
 * Three modes (docs/architecture.md §Pricing):
 *   FIXED_ROUTE   – admin-defined fare for a pickup-zone -> destination-zone pair
 *   DISTANCE_TIME – base + distance + time, with a minimum fare
 *   MANUAL        – operator-approved fare; requires an approver reference
 *
 * The server is the only place a price is produced. The result is a complete
 * snapshot (`PriceBreakdown`) that is stored on the ride and never recomputed
 * when rules change later.
 *
 * Ordering of DISTANCE_TIME / FIXED_ROUTE lines:
 *   base + distance + time -> minimum-fare adjustment -> surcharges
 *   -> discount -> rounding to `roundingStepMinor`.
 * Percentage surcharges are computed on the pre-surcharge subtotal (no
 * compounding). A percentage discount is computed on subtotal + surcharges.
 * A discount can never push the total below zero.
 * MANUAL fares are final: no surcharges, discounts or minimum-fare logic.
 */

import { CurrencyCode, assertNonNegativeMinor, mulDivRound, roundToStep } from './money.js';

export type PricingMode = 'FIXED_ROUTE' | 'DISTANCE_TIME' | 'MANUAL';

export interface Surcharge {
  code: string;
  kind: 'FLAT' | 'PERCENT_BPS';
  /** FLAT: minor units. PERCENT_BPS: basis points (100 bps = 1%). */
  value: number;
}

export interface Discount {
  code: string;
  kind: 'FLAT' | 'PERCENT_BPS';
  value: number;
  /** Optional cap on the discount, in minor units. */
  maxMinor?: number;
}

export interface PricingRule {
  id: string;
  version: number;
  mode: PricingMode;
  currency: CurrencyCode;
  baseFareMinor: number;
  perKmMinor: number;
  perMinuteMinor: number;
  minimumFareMinor: number;
  surcharges: Surcharge[];
  /** Platform commission in basis points of the final total (0..10000). */
  commission_bps: number;
  /** Final total is rounded to a multiple of this (>= 1). */
  roundingStepMinor: number;
}

export interface FixedRouteMatch {
  id: string;
  fareMinor: number;
}

export interface QuoteInput {
  distanceMeters: number;
  durationSeconds: number;
  /** Required when rule.mode === 'FIXED_ROUTE'. */
  fixedRoute?: FixedRouteMatch;
  /** Required when rule.mode === 'MANUAL'. */
  manualFareMinor?: number;
  /** Staff user id that approved the manual fare. Required for MANUAL. */
  manualApprovedBy?: string;
  discount?: Discount;
}

export interface PriceLine {
  code: string;
  amountMinor: number;
}

export interface PriceBreakdown {
  currency: CurrencyCode;
  mode: PricingMode;
  ruleId: string;
  ruleVersion: number;
  distanceMeters: number;
  durationSeconds: number;
  lines: PriceLine[];
  discountMinor: number;
  totalMinor: number;
  commission_bps: number;
  commissionMinor: number;
  driverNetMinor: number;
  fixedRouteId?: string;
  manualApprovedBy?: string;
  /** True for quotes: distance/time are estimates until the trip completes. */
  estimated: boolean;
}

export class PricingError extends Error {
  constructor(
    public readonly code:
      | 'INVALID_RULE'
      | 'INVALID_INPUT'
      | 'FIXED_ROUTE_REQUIRED'
      | 'MANUAL_FARE_REQUIRED'
      | 'MANUAL_APPROVER_REQUIRED',
    message: string,
  ) {
    super(message);
    this.name = 'PricingError';
  }
}

function validateRule(rule: PricingRule): void {
  try {
    assertNonNegativeMinor(rule.baseFareMinor, 'baseFareMinor');
    assertNonNegativeMinor(rule.perKmMinor, 'perKmMinor');
    assertNonNegativeMinor(rule.perMinuteMinor, 'perMinuteMinor');
    assertNonNegativeMinor(rule.minimumFareMinor, 'minimumFareMinor');
    for (const s of rule.surcharges) {
      assertNonNegativeMinor(s.value, `surcharge ${s.code}`);
    }
  } catch (e) {
    throw new PricingError('INVALID_RULE', (e as Error).message);
  }
  if (!Number.isInteger(rule.commission_bps) || rule.commission_bps < 0 || rule.commission_bps > 10_000) {
    throw new PricingError('INVALID_RULE', `commission_bps must be 0..10000, got ${rule.commission_bps}`);
  }
  if (!Number.isInteger(rule.roundingStepMinor) || rule.roundingStepMinor < 1) {
    throw new PricingError('INVALID_RULE', `roundingStepMinor must be >= 1, got ${rule.roundingStepMinor}`);
  }
  if (!Number.isInteger(rule.version) || rule.version < 1) {
    throw new PricingError('INVALID_RULE', `version must be >= 1, got ${rule.version}`);
  }
}

function validateInput(input: QuoteInput): void {
  try {
    assertNonNegativeMinor(input.distanceMeters, 'distanceMeters');
    assertNonNegativeMinor(input.durationSeconds, 'durationSeconds');
    if (input.discount) {
      assertNonNegativeMinor(input.discount.value, 'discount.value');
      if (input.discount.maxMinor !== undefined) {
        assertNonNegativeMinor(input.discount.maxMinor, 'discount.maxMinor');
      }
    }
  } catch (e) {
    throw new PricingError('INVALID_INPUT', (e as Error).message);
  }
}

export function computePrice(rule: PricingRule, input: QuoteInput): PriceBreakdown {
  validateRule(rule);
  validateInput(input);

  const lines: PriceLine[] = [];
  let discountMinor = 0;
  let totalMinor: number;
  let fixedRouteId: string | undefined;
  let manualApprovedBy: string | undefined;

  if (rule.mode === 'MANUAL') {
    if (input.manualFareMinor === undefined) {
      throw new PricingError('MANUAL_FARE_REQUIRED', 'MANUAL pricing requires manualFareMinor');
    }
    if (!input.manualApprovedBy) {
      throw new PricingError('MANUAL_APPROVER_REQUIRED', 'MANUAL pricing requires manualApprovedBy');
    }
    try {
      assertNonNegativeMinor(input.manualFareMinor, 'manualFareMinor');
    } catch (e) {
      throw new PricingError('INVALID_INPUT', (e as Error).message);
    }
    lines.push({ code: 'MANUAL_FARE', amountMinor: input.manualFareMinor });
    totalMinor = input.manualFareMinor;
    manualApprovedBy = input.manualApprovedBy;
  } else {
    let subtotal = 0;

    if (rule.mode === 'FIXED_ROUTE') {
      if (!input.fixedRoute) {
        throw new PricingError('FIXED_ROUTE_REQUIRED', 'FIXED_ROUTE pricing requires a matched fixed route');
      }
      try {
        assertNonNegativeMinor(input.fixedRoute.fareMinor, 'fixedRoute.fareMinor');
      } catch (e) {
        throw new PricingError('INVALID_INPUT', (e as Error).message);
      }
      lines.push({ code: 'FIXED_ROUTE_FARE', amountMinor: input.fixedRoute.fareMinor });
      subtotal = input.fixedRoute.fareMinor;
      fixedRouteId = input.fixedRoute.id;
    } else {
      const distance = mulDivRound(rule.perKmMinor, input.distanceMeters, 1000);
      const time = mulDivRound(rule.perMinuteMinor, input.durationSeconds, 60);
      lines.push({ code: 'BASE_FARE', amountMinor: rule.baseFareMinor });
      lines.push({ code: 'DISTANCE', amountMinor: distance });
      lines.push({ code: 'TIME', amountMinor: time });
      subtotal = rule.baseFareMinor + distance + time;

      if (subtotal < rule.minimumFareMinor) {
        const adj = rule.minimumFareMinor - subtotal;
        lines.push({ code: 'MINIMUM_FARE_ADJUSTMENT', amountMinor: adj });
        subtotal += adj;
      }
    }

    const preSurcharge = subtotal;
    let running = subtotal;
    for (const s of rule.surcharges) {
      const amount = s.kind === 'FLAT' ? s.value : mulDivRound(preSurcharge, s.value, 10_000);
      if (amount > 0) {
        lines.push({ code: `SURCHARGE_${s.code}`, amountMinor: amount });
        running += amount;
      }
    }

    if (input.discount) {
      const d = input.discount;
      let amount = d.kind === 'FLAT' ? d.value : mulDivRound(running, d.value, 10_000);
      if (d.maxMinor !== undefined) amount = Math.min(amount, d.maxMinor);
      amount = Math.min(amount, running);
      discountMinor = amount;
      if (amount > 0) {
        lines.push({ code: `DISCOUNT_${d.code}`, amountMinor: -amount });
        running -= amount;
      }
    }

    const rounded = roundToStep(running, rule.roundingStepMinor);
    if (rounded !== running) {
      lines.push({ code: 'ROUNDING', amountMinor: rounded - running });
    }
    totalMinor = rounded;
  }

  const commissionMinor = mulDivRound(totalMinor, rule.commission_bps, 10_000);
  const driverNetMinor = totalMinor - commissionMinor;

  return {
    currency: rule.currency,
    mode: rule.mode,
    ruleId: rule.id,
    ruleVersion: rule.version,
    distanceMeters: input.distanceMeters,
    durationSeconds: input.durationSeconds,
    lines,
    discountMinor,
    totalMinor,
    commission_bps: rule.commission_bps,
    commissionMinor,
    driverNetMinor,
    fixedRouteId,
    manualApprovedBy,
    estimated: true,
  };
}
