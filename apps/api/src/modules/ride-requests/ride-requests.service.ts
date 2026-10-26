import * as crypto from 'node:crypto';
import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { PricingService } from '../pricing/pricing.service.js';
import { transition, type RideSnapshot, type Actor } from '../../domain/ride-state.js';

// Keep row typing local without passing a generic to Prisma's generated raw-query method.
const queryRaw = <T>(tx: any) =>
  (strings: TemplateStringsArray, ...values: any[]): Promise<T> =>
    tx.$queryRaw(strings, ...values) as Promise<T>;

@Injectable()
export class RideRequestsService {
  constructor(private prisma: PrismaService, private pricing: PricingService) {}

  async create(params: {
    customer_id: string;
    service_area_id: string;
    vehicle_type_id: string;
    pickupLat: number;
    pickupLon: number;
    destLat: number;
    destLon: number;
    idempotency_key: string;
  }) {
    const request_hash = crypto.createHash('sha256').update(JSON.stringify({
      service_area_id: params.service_area_id,
      vehicle_type_id: params.vehicle_type_id,
      pickupLat: params.pickupLat,
      pickupLon: params.pickupLon,
      destLat: params.destLat,
      destLon: params.destLon,
    })).digest('hex');

    return this.prisma.tx(async (tx) => {
      // Serialize ride creation for this customer across API instances. The DB also
      // has a partial unique index on active rides as a final integrity boundary.
      const customer = await queryRaw<Array<{ id: string }>>(tx)`SELECT id FROM users WHERE id = ${params.customer_id} FOR UPDATE`;
      if (customer.length === 0) throw new NotFoundException('المستخدم غير موجود', 'Customer not found');

      const existing = await tx.idempotency_keys.findUnique({
        where: {
          user_id_scope_idempotency_key: {
            user_id: params.customer_id,
            scope: 'POST /rides',
            idempotency_key: params.idempotency_key,
          },
        },
      });
      if (existing) {
        if (existing.request_hash !== request_hash) {
          throw new ConflictException('مفتاح منع التكرار مستخدم لطلب مختلف', 'Idempotency key was already used with a different request');
        }
        return { replayed: true, resource_id: existing.resource_id };
      }

      const active = await tx.rides.findFirst({
        where: {
          customer_id: params.customer_id,
          status: { in: ['SEARCHING', 'ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS'] },
        },
      });
      if (active) throw new ConflictException('لديك رحلة نشطة بالفعل', 'You already have an active ride');

      // Only calculate a new quote for a genuinely new idempotency key; retries
      // must replay the original resource even if pricing rules have since changed.
      const quote = await this.pricing.quote({
        pickupLat: params.pickupLat, pickupLon: params.pickupLon,
        destLat: params.destLat, destLon: params.destLon,
        service_area_id: params.service_area_id, vehicle_type_id: params.vehicle_type_id,
      });

      // Insert and capture the exact generated id in the same statement; never
      // select "the latest SEARCHING ride", which can belong to another request.
      const [rideIdRow] = await queryRaw<Array<{ id: string }>>(tx)`
        INSERT INTO rides (
          id, customer_id, service_area_id, vehicle_type_id, status, pickup, destination,
          currency_code, pricing_rule_id, pricing_rule_version, price_breakdown,
          quoted_total, estimated_distance_m, estimated_duration_s, search_expires_at
        ) VALUES (
          gen_random_uuid(), ${params.customer_id}, ${params.service_area_id}, ${params.vehicle_type_id},
          'SEARCHING',
          ST_SetSRID(ST_MakePoint(${params.pickupLon}, ${params.pickupLat})::geometry, 4326)::geography,
          ST_SetSRID(ST_MakePoint(${params.destLon}, ${params.destLat})::geometry, 4326)::geography,
          ${quote.currency}, ${quote.ruleId}, ${quote.ruleVersion}, ${JSON.stringify(quote)}::jsonb,
          ${quote.totalMinor / 100}, ${quote.distanceMeters}, ${quote.durationSeconds},
          now() + interval '5 minutes'
        ) RETURNING id`;
      const ride = await tx.rides.findUnique({ where: { id: rideIdRow.id } });
      if (!ride) throw new Error('Ride insert succeeded but the inserted row could not be read');

      await tx.idempotency_keys.create({
        data: {
          user_id: params.customer_id,
          scope: 'POST /rides',
          idempotency_key: params.idempotency_key,
          request_hash,
          state: 'COMPLETED',
          responseStatus: 201,
          resource_id: ride.id,
          expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000),
        },
      });

      return { replayed: false, ride };
    });
  }

  async active(customer_id: string) {
    return this.prisma.rides.findFirst({
      where: {
        customer_id,
        status: { in: ['SEARCHING', 'ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS'] },
      },
      orderBy: { requested_at: 'desc' },
    });
  }

  async findOne(id: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    return ride;
  }

  async cancel(params: { ride_id: string; customer_id: string; reasonCode: string; note?: string }) {
    const ride = await this.findOne(params.ride_id);
    if (ride.customer_id !== params.customer_id) {
      throw new Error('FORBIDDEN');
    }
    const snapshot: RideSnapshot = { status: ride.status as any, customer_id: ride.customer_id, driver_id: ride.driver_id ?? null };
    const actor: Actor = { role: 'CUSTOMER', user_id: params.customer_id };
    const result = transition(snapshot, 'CANCEL', actor, { cancel_reason_code: params.reasonCode });
    return this.prisma.tx(async (tx) => {
      const updated = await tx.rides.update({
        where: { id: params.ride_id },
        data: {
          status: 'CANCELLED', cancelled_by_role: 'CUSTOMER', cancelled_by_user_id: params.customer_id,
          cancel_reason_code: params.reasonCode, cancel_note: params.note ?? null, cancelled_at: new Date(),
        },
      });
      await tx.ride_events.create({
        data: { ride_id: params.ride_id, event_type: 'CANCEL', from_status: ride.status, to_status: 'CANCELLED', actor_role: 'CUSTOMER', actor_user_id: params.customer_id, payload: { reasonCode: params.reasonCode } },
      });
      return { ride: updated, transition: result };
    });
  }
}
