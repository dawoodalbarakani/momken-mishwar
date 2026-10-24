import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { PricingService } from '../pricing/pricing.service.js';
import { transition, type RideSnapshot, type Actor } from '../../domain/ride-state.js';

@Injectable()
export class RideRequestsService {
  constructor(private prisma: PrismaService, private pricing: PricingService) {}

  async create(params: {
    customerId: string;
    serviceAreaId: string;
    vehicleTypeId: string;
    pickupLat: number;
    pickupLon: number;
    destLat: number;
    destLon: number;
    idempotencyKey: string;
  }) {
    const existing = await this.prisma.idempotencyKeys.findUnique({
      where: {
        userId_scope_idempotencyKey: {
          userId: params.customerId,
          scope: 'POST /rides',
          idempotencyKey: params.idempotencyKey,
        },
      },
    });
    if (existing) return { replayed: true, resourceId: existing.resourceId };

    const active = await this.prisma.rides.findFirst({
      where: {
        customerId: params.customerId,
        status: { in: ['SEARCHING', 'ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS'] },
      },
    });
    if (active) throw new ConflictException('لديك رحلة نشطة بالفعل', 'You already have an active ride');

    const quote = await this.pricing.quote({
      pickupLat: params.pickupLat, pickupLon: params.pickupLon,
      destLat: params.destLat, destLon: params.destLon,
      serviceAreaId: params.serviceAreaId, vehicleTypeId: params.vehicleTypeId,
    });

    // Geography columns are Unsupported("geography") in Prisma, so the ride row is
    // inserted with $executeRaw (PostGIS literals) and then read back.
    await this.prisma.$executeRaw`
      INSERT INTO rides (
        id, customer_id, service_area_id, vehicle_type_id, status, pickup, destination,
        currency_code, pricing_rule_id, pricing_rule_version, price_breakdown,
        quoted_total, estimated_distance_m, estimated_duration_s, search_expires_at
      ) VALUES (
        gen_random_uuid(), ${params.customerId}, ${params.serviceAreaId}, ${params.vehicleTypeId},
        'SEARCHING',
        ST_SetSRID(ST_MakePoint(${params.pickupLon}, ${params.pickupLat})::geometry, 4326)::geography,
        ST_SetSRID(ST_MakePoint(${params.destLon}, ${params.destLat})::geometry, 4326)::geography,
        ${quote.currency}, ${quote.ruleId}, ${quote.ruleVersion}, ${JSON.stringify(quote)}::jsonb,
        ${quote.totalMinor / 100}, ${quote.distanceMeters}, ${quote.durationSeconds},
        now() + interval '5 minutes'
      )`;

    const [ride] = await this.prisma.$queryRaw`SELECT * FROM rides WHERE customer_id = ${params.customerId} AND status = 'SEARCHING' ORDER BY requested_at DESC LIMIT 1`;

    await this.prisma.idempotencyKeys.create({
      data: {
        userId: params.customerId,
        scope: 'POST /rides',
        idempotencyKey: params.idempotencyKey,
        requestHash: '',
        state: 'COMPLETED',
        responseStatus: 201,
        resourceId: ride.id,
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      },
    });

    return { replayed: false, ride };
  }

  async active(customerId: string) {
    return this.prisma.rides.findFirst({
      where: {
        customerId,
        status: { in: ['SEARCHING', 'ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS'] },
      },
      orderBy: { requestedAt: 'desc' },
    });
  }

  async findOne(id: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    return ride;
  }

  async cancel(params: { rideId: string; customerId: string; reasonCode: string; note?: string }) {
    const ride = await this.findOne(params.rideId);
    if (ride.customerId !== params.customerId) {
      throw new Error('FORBIDDEN');
    }
    const snapshot: RideSnapshot = { status: ride.status as any, customerId: ride.customerId, driverId: ride.driverId ?? null };
    const actor: Actor = { role: 'CUSTOMER', userId: params.customerId };
    const result = transition(snapshot, 'CANCEL', actor, { cancelReasonCode: params.reasonCode });
    return this.prisma.tx(async (tx) => {
      const updated = await tx.rides.update({
        where: { id: params.rideId },
        data: {
          status: 'CANCELLED', cancelledByRole: 'CUSTOMER', cancelledByUserId: params.customerId,
          cancelReasonCode: params.reasonCode, cancelNote: params.note ?? null, cancelledAt: new Date(),
        },
      });
      await tx.rideEvents.create({
        data: { rideId: params.rideId, eventType: 'CANCEL', fromStatus: ride.status, toStatus: 'CANCELLED', actorRole: 'CUSTOMER', actorUserId: params.customerId, payload: { reasonCode: params.reasonCode } },
      });
      return { ride: updated, transition: result };
    });
  }
}
