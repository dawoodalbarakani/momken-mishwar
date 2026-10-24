/**
 * Ride lifecycle state machine (pure).
 *
 *   SEARCHING -> ASSIGNED -> ARRIVING -> ARRIVED -> IN_PROGRESS -> COMPLETED
 *   SEARCHING -> NO_DRIVER_FOUND            (search timed out)
 *   SEARCHING | ASSIGNED | ARRIVING | ARRIVED -> CANCELLED
 *   IN_PROGRESS -> CANCELLED                (staff only, reason required)
 *
 * This module decides whether a transition is *allowed* and who may perform
 * it. It does not perform I/O. The database is the source of truth: services
 * must apply the transition with a conditional UPDATE inside a transaction
 * (see docs/database-design.md §Atomic assignment), and a DB trigger rejects
 * illegal transitions as a second line of defence.
 */

export type RideStatus =
  | 'SEARCHING'
  | 'NO_DRIVER_FOUND'
  | 'ASSIGNED'
  | 'ARRIVING'
  | 'ARRIVED'
  | 'IN_PROGRESS'
  | 'COMPLETED'
  | 'CANCELLED';

export type RideEvent =
  | 'DRIVER_ASSIGNED'
  | 'SEARCH_EXPIRED'
  | 'DRIVER_EN_ROUTE'
  | 'DRIVER_ARRIVED'
  | 'TRIP_STARTED'
  | 'TRIP_COMPLETED'
  | 'CANCEL';

export type ActorRole = 'CUSTOMER' | 'DRIVER' | 'SYSTEM' | 'STAFF';

export interface Actor {
  role: ActorRole;
  userId?: string;
}

export interface RideSnapshot {
  status: RideStatus;
  customerId: string;
  /** Null until a driver is assigned. */
  driverId: string | null;
}

export interface TransitionContext {
  /** Required for TRIP_STARTED: the start code was verified by the server. */
  startCodeVerified?: boolean;
  /** Required for CANCEL. */
  cancelReasonCode?: string;
  /** Required for DRIVER_ASSIGNED: the driver that won the atomic assignment. */
  assignedDriverId?: string;
}

export interface TransitionResult {
  to: RideStatus;
  /** Present for CANCEL: who cancelled (stored on the ride and in ride_events). */
  cancelledBy?: ActorRole;
  cancelReasonCode?: string;
}

export class RideTransitionError extends Error {
  constructor(
    public readonly code:
      | 'INVALID_TRANSITION'
      | 'FORBIDDEN_ACTOR'
      | 'START_CODE_NOT_VERIFIED'
      | 'REASON_REQUIRED'
      | 'DRIVER_REQUIRED',
    message: string,
  ) {
    super(message);
    this.name = 'RideTransitionError';
  }
}

export const TERMINAL_STATUSES: readonly RideStatus[] = ['COMPLETED', 'CANCELLED', 'NO_DRIVER_FOUND'];
export const ACTIVE_DRIVER_STATUSES: readonly RideStatus[] = ['ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS'];

const CANCELLABLE_BY_PARTIES: readonly RideStatus[] = ['SEARCHING', 'ASSIGNED', 'ARRIVING', 'ARRIVED'];

const DRIVER_STEPS: Partial<Record<RideEvent, { from: RideStatus; to: RideStatus }>> = {
  DRIVER_EN_ROUTE: { from: 'ASSIGNED', to: 'ARRIVING' },
  DRIVER_ARRIVED: { from: 'ARRIVING', to: 'ARRIVED' },
  TRIP_STARTED: { from: 'ARRIVED', to: 'IN_PROGRESS' },
  TRIP_COMPLETED: { from: 'IN_PROGRESS', to: 'COMPLETED' },
};

function isAssignedDriver(ride: RideSnapshot, actor: Actor): boolean {
  return actor.role === 'DRIVER' && !!actor.userId && ride.driverId === actor.userId;
}

function isOwnerCustomer(ride: RideSnapshot, actor: Actor): boolean {
  return actor.role === 'CUSTOMER' && !!actor.userId && ride.customerId === actor.userId;
}

function invalid(ride: RideSnapshot, event: RideEvent): never {
  throw new RideTransitionError('INVALID_TRANSITION', `Event ${event} is not allowed from status ${ride.status}`);
}

function forbidden(event: RideEvent, actor: Actor): never {
  throw new RideTransitionError('FORBIDDEN_ACTOR', `Actor ${actor.role} may not perform ${event} on this ride`);
}

export function transition(
  ride: RideSnapshot,
  event: RideEvent,
  actor: Actor,
  ctx: TransitionContext = {},
): TransitionResult {
  if (TERMINAL_STATUSES.includes(ride.status)) invalid(ride, event);

  switch (event) {
    case 'DRIVER_ASSIGNED': {
      if (ride.status !== 'SEARCHING') invalid(ride, event);
      // Assignment is a dispatch decision made on behalf of the accepting driver.
      if (actor.role !== 'SYSTEM' && !(actor.role === 'DRIVER' && actor.userId === ctx.assignedDriverId)) {
        forbidden(event, actor);
      }
      if (!ctx.assignedDriverId) {
        throw new RideTransitionError('DRIVER_REQUIRED', 'DRIVER_ASSIGNED requires assignedDriverId');
      }
      return { to: 'ASSIGNED' };
    }

    case 'SEARCH_EXPIRED': {
      if (ride.status !== 'SEARCHING') invalid(ride, event);
      if (actor.role !== 'SYSTEM') forbidden(event, actor);
      return { to: 'NO_DRIVER_FOUND' };
    }

    case 'DRIVER_EN_ROUTE':
    case 'DRIVER_ARRIVED':
    case 'TRIP_STARTED':
    case 'TRIP_COMPLETED': {
      const step = DRIVER_STEPS[event]!;
      if (ride.status !== step.from) invalid(ride, event);
      if (!isAssignedDriver(ride, actor)) forbidden(event, actor);
      if (event === 'TRIP_STARTED' && ctx.startCodeVerified !== true) {
        throw new RideTransitionError('START_CODE_NOT_VERIFIED', 'TRIP_STARTED requires a verified start code');
      }
      return { to: step.to };
    }

    case 'CANCEL': {
      if (!ctx.cancelReasonCode) {
        throw new RideTransitionError('REASON_REQUIRED', 'CANCEL requires a reason code');
      }
      const cancelledBy = actor.role;
      if (ride.status === 'IN_PROGRESS') {
        // A trip in progress can only be ended by staff (dispute / safety handling).
        if (actor.role !== 'STAFF') forbidden(event, actor);
      } else if (CANCELLABLE_BY_PARTIES.includes(ride.status)) {
        const allowed =
          isOwnerCustomer(ride, actor) ||
          isAssignedDriver(ride, actor) ||
          actor.role === 'STAFF' ||
          actor.role === 'SYSTEM';
        if (!allowed) forbidden(event, actor);
      } else {
        invalid(ride, event);
      }
      return { to: 'CANCELLED', cancelledBy, cancelReasonCode: ctx.cancelReasonCode };
    }
  }
}
