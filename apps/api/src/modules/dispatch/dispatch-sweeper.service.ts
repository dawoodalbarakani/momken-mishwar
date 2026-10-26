import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { DispatchService } from './dispatch.service.js';

/**
 * Sweep interval. Clamped to at least one second: a NaN or zero value would
 * otherwise turn the timer into a busy loop that hammers the database.
 */
const SWEEP_INTERVAL_MS = Math.max(
  1000,
  Number(process.env.DISPATCH_SWEEP_INTERVAL_MS ?? 5000) || 5000,
);
const SWEEPER_ENABLED = process.env.DISPATCH_SWEEPER_ENABLED !== 'false';

/**
 * Periodic upkeep for dispatch state.
 *
 * `search_expires_at` is written when a ride is requested, but the request path
 * never reads it back: expiry is only noticed the next time `sweep()` runs.
 * Without a timer a ride that finds no driver stays SEARCHING forever, and the
 * partial unique index `rides_one_active_per_customer_uq` then rejects every
 * later request from that customer (`ride-requests.service.ts` answers 409 "you
 * already have an active ride"). One failed search would lock the rider out of
 * the platform until a staff member intervened.
 *
 * An in-process interval is enough for a single API instance and is safe under
 * replication: `sweep()` claims rows with `FOR UPDATE SKIP LOCKED` and applies
 * conditional updates, so two sweepers cannot double-apply a transition.
 * ADR-0003 defers a real job queue (BullMQ/Redis) until a multi-instance
 * deployment actually needs one.
 */
@Injectable()
export class DispatchSweeperService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DispatchSweeperService.name);
  private timer?: NodeJS.Timeout;
  private running = false;

  constructor(private readonly dispatch: DispatchService) {}

  onModuleInit() {
    if (!SWEEPER_ENABLED) {
      this.logger.log('Dispatch sweeper disabled (DISPATCH_SWEEPER_ENABLED=false)');
      return;
    }

    this.timer = setInterval(() => void this.tick(), SWEEP_INTERVAL_MS);
    // Never keep the process alive just to run a sweep (tests, one-off scripts).
    this.timer.unref();
    this.logger.log(`Dispatch sweeper started (every ${SWEEP_INTERVAL_MS} ms)`);
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
    this.timer = undefined;
  }

  /**
   * A slow sweep must not overlap itself. Anything left unclaimed is picked up
   * on the next tick, because `sweep()` selects purely on persisted timestamps.
   */
  private async tick() {
    if (this.running) return;
    this.running = true;

    try {
      const { expiredOffers, searchesExpired } = await this.dispatch.sweep();
      if (expiredOffers > 0 || searchesExpired > 0) {
        this.logger.log(
          `Sweep: ${expiredOffers} offer(s) expired, ${searchesExpired} search(es) timed out`,
        );
      }
    } catch (error) {
      // A failing sweep must never take the API down with it.
      this.logger.error(
        `Sweep failed: ${error instanceof Error ? error.message : String(error)}`,
      );
    } finally {
      this.running = false;
    }
  }
}
