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
    return { status: ride.status as any, customerId: ride.customerId, driverId: ride.driverId ?? null };
  }

  async enRoute(rideId: string, driverId: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.driverId !== driverId) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    const snapshot: RideSnapshot = { status: ride.status as any, customerId: ride.customerId, driverId: ride.driverId ?? null };
    const actor: Actor = { role: 'DRIVER', userId: driverId };
    const result = transition(snapshot, 'DRIVER_EN_ROUTE', actor);
    return this.applyTransition(ride, result, driverId); // handled generically below
  }

  async arrived(rideId: string, driverId: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.driverId !== driverId) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    const snapshot: RideSnapshot = { status: ride.status as any, customerId: ride.customerId, driverId: ride.driverId ?? null };
    const actor: Actor = { role: 'DRIVER', userId: driverId };
    const result = transition(snapshot, 'DRIVER_ARRIVED', actor);
    return this.applyTransition(ride, result, driverId);
  }

  async startTrip(params: { rideId: string; driverId: string; code: string }) {
    const ride = await this.prisma.rides.findUnique({ where: { id: params.rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.driverId !== params.driverId) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    if (!ride.startCodeNonce || !ride.startCodeExpiresAt) {
      throw new BadRequestException('لا يوجد رمز بدء لهذه الرحلة', 'No start code for this ride');
    }

    // Increment attempts atomically, then verify.
    const [row] = await this.prisma.$queryRaw`
      UPDATE rides SET start_code_attempts = start_code_attempts + 1
      WHERE id = ${params.rideId}
      RETURNING start_code_attempts, start_code_nonce, start_code_expires_at`;
    const r = row as any;
    const attemptsUsed = Number(r.start_code_attempts);
    const maxAttempts = Number(process.env.START_CODE_MAX_ATTEMPTS ?? 5);

    const result: StartCodeResult = verifyStartCode({
      secret: START_CODE_SECRET,
      rideId: params.rideId,
      nonce: r.start_code_nonce as Buffer,
      submitted: params.code,
      expiresAt: r.start_code_expires_at,
      now: new Date(),
      attemptsUsed,
      maxAttempts,
    });
    if (!result.ok) {
      throw new BadRequestException(
        result.reason === 'LOCKED' ? 'تم قفل الرمز' : result.reason === 'EXPIRED' ? 'الرمز منتهي' : 'الرمز غير صحيح',
        result.reason,
      );
    }

    const snapshot: RideSnapshot = { status: ride.status as any, customerId: ride.customerId, driverId: ride.driverId ?? null };
    const actor: Actor = { role: 'DRIVER', userId: params.driverId };
    const ctx: TransitionContext = { startCodeVerified: true };
    const transitionResult = transition(snapshot, 'TRIP_STARTED', actor, ctx);
    return this.applyTransition(ride, transitionResult, params.driverId);
  }

  async complete(params: { rideId: string; driverId: string }) {
    const ride = await this.prisma.rides.findUnique({ where: { id: params.rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.driverId !== params.driverId) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    const snapshot: RideSnapshot = { status: ride.status as any, customerId: ride.customerId, driverId: ride.driverId ?? null };
    const actor: Actor = { role: 'DRIVER', userId: params.driverId };
    const result = transition(snapshot, 'TRIP_COMPLETED', actor);
    return this.applyTransition(ride, result, params.driverId);
  }

  async startCode(rideId: string, customerId: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.customerId !== customerId) throw new ForbiddenException('ليست رحلتك', 'Not your ride');
    if (!ride.startCodeNonce) {
      // generate a fresh nonce + expiry

      const nonce = newStartCodeNonce();
      const expiresAt = new Date(Date.now() + 15 * 60_000);
      await this.prisma.rides.update({ where: { id: rideId }, data: { startCodeNonce: nonce as any, startCodeExpiresAt: expiresAt, startCodeAttempts: 0 } });
      const code = deriveStartCode(START_CODE_SECRET, rideId, nonce);
      return { code, expiresAt };
    }
    const code = deriveStartCode(START_CODE_SECRET, rideId, ride.startCodeNonce as Buffer);
    return { code, expiresAt: ride.startCodeExpiresAt };
  }

  private async applyTransition(ride: any, result: { to: string; cancelledBy?: string; cancelReasonCode?: string }, actorUserId?: string) {
    const updates: any = { status: result.to, version: ride.version + 1 };
    const now = new Date();
    switch (result.to) {
      case 'ASSIGNED': updates.assignedAt = now; break;
      case 'ARRIVED': updates.arrivedAt = now; break;
      case 'IN_PROGRESS': updates.startedAt = now; break;
      case 'COMPLETED': {
        updates.completedAt = now;
        updates.finalTotal = ride.quotedTotal;
        const breakdown = (ride.priceBreakdown ?? {}) as { commissionMinor?: number; driverNetMinor?: number };
        updates.commissionAmount = Number(breakdown?.commissionMinor ?? 0) / 100;
        updates.driverNet = Number(breakdown?.driverNetMinor ?? 0) / 100;
        break;
      }
      case 'CANCELLED': updates.cancelledAt = now; updates.cancelledByRole = result.cancelledBy; updates.cancelReasonCode = result.cancelReasonCode; break;
    }
    const updated = await this.prisma.rides.update({ where: { id: ride.id }, data: updates });
    await this.prisma.rideEvents.create({
      data: { rideId: ride.id, eventType: result.to, fromStatus: ride.status, toStatus: result.to, actorRole: 'DRIVER', actorUserId, payload: {} },
    });
    return { ride: updated, transition: result };
  }
}
