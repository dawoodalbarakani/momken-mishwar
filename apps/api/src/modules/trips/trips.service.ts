import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import {
  transition,
  type RideSnapshot,
  type Actor,
  type TransitionContext,
  ACTIVE_DRIVER_STATUSES,
} from '../../domain/ride-state.js';
import {
  verifyStartCode,
  deriveStartCode,
  newStartCodeNonce,
  type StartCodeResult,
} from '../../domain/start-code.js';

const START_CODE_SECRET = Buffer.from(process.env.START_CODE_SECRET ?? 'dev-secret');
const START_CODE_MAX_ATTEMPTS = Number(process.env.START_CODE_MAX_ATTEMPTS ?? 5);

@Injectable()
export class TripsService {
  constructor(private prisma: PrismaService) {}

  private async rideSnapshot(id: string): Promise<RideSnapshot> {
    const ride = await this.prisma.rides.findUnique({ where: { id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    return { status: ride.status as any, customer_id: ride.customer_id, driver_id: ride.driver_id ?? null };
  }

  async enRoute(ride_id: string, driver_id: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: ride_id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.driver_id !== driver_id) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    const snapshot: RideSnapshot = { status: ride.status as any, customer_id: ride.customer_id, driver_id: ride.driver_id ?? null };
    const actor: Actor = { role: 'DRIVER', user_id: driver_id };
    const result = transition(snapshot, 'DRIVER_EN_ROUTE', actor);
    return this.applyTransition(ride, result, driver_id); // handled generically below
  }

  async arrived(ride_id: string, driver_id: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: ride_id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.driver_id !== driver_id) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    const snapshot: RideSnapshot = { status: ride.status as any, customer_id: ride.customer_id, driver_id: ride.driver_id ?? null };
    const actor: Actor = { role: 'DRIVER', user_id: driver_id };
    const result = transition(snapshot, 'DRIVER_ARRIVED', actor);
    return this.applyTransition(ride, result, driver_id);
  }

  async startTrip(params: { ride_id: string; driver_id: string; code: string }) {
    const ride = await this.prisma.rides.findUnique({ where: { id: params.ride_id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.driver_id !== params.driver_id) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    if (!ride.start_code_nonce || !ride.start_code_expires_at) {
      throw new BadRequestException('لا يوجد رمز بدء لهذه الرحلة', 'No start code for this ride');
    }

    // Increment attempts atomically, then verify.
    const [row] = (await this.prisma.$queryRaw`
      UPDATE rides SET start_code_attempts = start_code_attempts + 1
      WHERE id = ${params.ride_id}
      RETURNING start_code_attempts, start_code_nonce, start_code_expires_at` as any[]);
    const r = row as any;
    const attemptsUsed = Number(r.start_code_attempts);
    const max_attempts = Number(process.env.START_CODE_MAX_ATTEMPTS ?? 5);

    const result: StartCodeResult = verifyStartCode({
      secret: START_CODE_SECRET,
      ride_id: params.ride_id,
      nonce: r.start_code_nonce as Buffer,
      submitted: params.code,
      expires_at: r.start_code_expires_at,
      now: new Date(),
      attemptsUsed,
      max_attempts,
    });
    if (!result.ok) {
      throw new BadRequestException(
        result.reason === 'LOCKED' ? 'تم قفل الرمز' : result.reason === 'EXPIRED' ? 'الرمز منتهي' : 'الرمز غير صحيح',
        result.reason,
      );
    }

    const snapshot: RideSnapshot = { status: ride.status as any, customer_id: ride.customer_id, driver_id: ride.driver_id ?? null };
    const actor: Actor = { role: 'DRIVER', user_id: params.driver_id };
    const ctx: TransitionContext = { startCodeVerified: true };
    const transitionResult = transition(snapshot, 'TRIP_STARTED', actor, ctx);
    return this.applyTransition(ride, transitionResult, params.driver_id);
  }

  async complete(params: { ride_id: string; driver_id: string }) {
    const ride = await this.prisma.rides.findUnique({ where: { id: params.ride_id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.driver_id !== params.driver_id) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    const snapshot: RideSnapshot = { status: ride.status as any, customer_id: ride.customer_id, driver_id: ride.driver_id ?? null };
    const actor: Actor = { role: 'DRIVER', user_id: params.driver_id };
    const result = transition(snapshot, 'TRIP_COMPLETED', actor);
    return this.applyTransition(ride, result, params.driver_id);
  }

  async startCode(ride_id: string, customer_id: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: ride_id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.customer_id !== customer_id) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    if (!ride.start_code_nonce) {
      // generate a fresh nonce + expiry

      const nonce = newStartCodeNonce();
      const expires_at = new Date(Date.now() + 15 * 60_000);
      await this.prisma.rides.update({ where: { id: ride_id }, data: { start_code_nonce: nonce as any, start_code_expires_at: expires_at, start_code_attempts: 0 } });
      const code = deriveStartCode(START_CODE_SECRET, ride_id, nonce);
      return { code, expires_at };
    }
    const code = deriveStartCode(START_CODE_SECRET, ride_id, ride.start_code_nonce as Buffer);
    return { code, expires_at: ride.start_code_expires_at };
  }

  private async applyTransition(ride: any, result: { to: string; cancelledBy?: string; cancel_reason_code?: string }, actor_user_id?: string) {
    const updates: any = { status: result.to, version: ride.version + 1 };
    const now = new Date();
    switch (result.to) {
      case 'ASSIGNED': updates.assigned_at = now; break;
      case 'ARRIVED': updates.arrived_at = now; break;
      case 'IN_PROGRESS': updates.started_at = now; break;
      case 'COMPLETED': {
        updates.completed_at = now;
        updates.final_total = ride.quoted_total;
        const breakdown = (ride.price_breakdown ?? {}) as { commissionMinor?: number; driverNetMinor?: number };
        updates.commission_amount = Number(breakdown?.commissionMinor ?? 0) / 100;
        updates.driver_net = Number(breakdown?.driverNetMinor ?? 0) / 100;
        break;
      }
      case 'CANCELLED': updates.cancelled_at = now; updates.cancelled_by_role = result.cancelledBy; updates.cancel_reason_code = result.cancel_reason_code; break;
    }
    const updated = await this.prisma.rides.update({ where: { id: ride.id }, data: updates });
    await this.prisma.ride_events.create({
      data: { ride_id: ride.id, event_type: result.to, from_status: ride.status, to_status: result.to, actor_role: 'DRIVER', actor_user_id, payload: {} },
    });
    return { ride: updated, transition: result };
  }
}
