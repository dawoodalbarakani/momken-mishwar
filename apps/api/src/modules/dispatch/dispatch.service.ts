import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { transition, type RideSnapshot, type Actor } from '../../domain/ride-state.js';
import { newStartCodeNonce } from '../../domain/start-code.js';

// Keep row typing local without passing a generic to Prisma's generated raw-query method.
const queryRaw = <T>(tx: any) =>
  (strings: TemplateStringsArray, ...values: any[]): Promise<T> =>
    tx.$queryRaw(strings, ...values) as Promise<T>;

@Injectable()
export class DispatchService {
  constructor(private prisma: PrismaService) {}

  async search(rideId: string) {
    return this.prisma.tx(async (tx) => {
      const [ride] = await queryRaw<any[]>(tx)`SELECT * FROM rides WHERE id = ${rideId} FOR UPDATE`;
      if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
      if (ride.status !== 'SEARCHING' || ride.driver_id !== null) {
        throw new BadRequestException('الرحلة ليست في حالة بحث', 'Ride is not searching');
      }

      // Concurrent/retried search calls for the same ride serialize on the ride
      // row. Return existing live offers rather than creating duplicate batches.
      const existing = await tx.rideOffers.findMany({
        where: { rideId, status: 'PENDING', expiresAt: { gt: new Date() } },
        orderBy: { offeredAt: 'asc' },
      });
      if (existing.length > 0) {
        return { rideId, offers: existing, expiresAt: existing.reduce((latest, o) => o.expiresAt > latest ? o.expiresAt : latest, existing[0].expiresAt), replayed: true };
      }
      await tx.rideOffers.updateMany({
        where: { rideId, status: 'PENDING', expiresAt: { lte: new Date() } },
        data: { status: 'EXPIRED', respondedAt: new Date() },
      });

      const settings = await tx.dispatchSettings.findUnique({ where: { serviceAreaId: ride.service_area_id } });
      if (!settings) throw new BadRequestException('لا توجد إعدادات إسناد لهذه المنطقة', 'No dispatch settings for area');

      const [pickup] = await queryRaw<Array<{ lon: number; lat: number }>>(tx)`
        SELECT ST_X(pickup::geometry) AS lon, ST_Y(pickup::geometry) AS lat
        FROM rides WHERE id = ${rideId}`;
      const pickupLon = Number(pickup?.lon);
      const pickupLat = Number(pickup?.lat);

      const candidates = await queryRaw<Array<{ driver_id: string; distance_m: number }>>(tx)`
        SELECT dp.user_id AS driver_id,
               ST_Distance(dp.last_location,
                 ST_SetSRID(ST_MakePoint(${pickupLon}, ${pickupLat})::geometry, 4326)::geography) AS distance_m
        FROM driver_profiles dp
        JOIN users u ON u.id = dp.user_id
        WHERE u.status = 'ACTIVE'
          AND dp.is_online = true
          AND dp.verification_status = 'APPROVED'
          AND dp.service_area_id = ${ride.service_area_id}
          AND dp.last_location IS NOT NULL
          AND dp.last_location_at > now() - (${settings.locationMaxAgeSeconds} * interval '1 second')
          AND NOT EXISTS (
            SELECT 1 FROM rides r
            WHERE r.driver_id = dp.user_id
              AND r.status IN ('ASSIGNED','ARRIVING','ARRIVED','IN_PROGRESS')
          )
          AND NOT EXISTS (
            SELECT 1 FROM ride_offers ro
            WHERE ro.ride_id = ${rideId}
              AND ro.driver_id = dp.user_id
              AND ro.status = 'PENDING'
              AND ro.expires_at > now()
          )
          AND ST_DWithin(dp.last_location,
            ST_SetSRID(ST_MakePoint(${pickupLon}, ${pickupLat})::geometry, 4326)::geography, ${settings.searchRadiusM})
        ORDER BY distance_m
        LIMIT ${settings.maxCandidates}`;

      const batch = candidates.slice(0, settings.offerBatchSize);
      if (batch.length === 0) return { rideId, offers: [], expiresAt: null, replayed: false };

      const priorRound = await tx.rideOffers.aggregate({ where: { rideId }, _max: { roundNo: true } });
      const roundNo = (priorRound._max.roundNo ?? 0) + 1;
      const expiresAt = new Date(Date.now() + settings.offerTtlSeconds * 1000);
      const offers = await Promise.all(batch.map((candidate) => tx.rideOffers.create({
        data: {
          rideId,
          driverId: candidate.driver_id,
          roundNo,
          distanceToPickupM: Number(candidate.distance_m ?? 0),
          expiresAt,
        },
      })));
      return { rideId, offers, expiresAt, replayed: false };
    });
  }

  async acceptOffer(params: { offerId: string; driverId: string; vehicleId: string }) {
    return this.prisma.tx(async (tx) => {
      // Discover the ride id without locking the offer, then always lock in the
      // same order: ride -> offer -> driver. This avoids the deadlock where two
      // acceptors each lock a different offer and then cancel each other's row.
      const [offerRef] = await queryRaw<Array<{ ride_id: string }>>(tx)`
        SELECT ride_id FROM ride_offers WHERE id = ${params.offerId} AND driver_id = ${params.driverId}`;
      if (!offerRef) throw new BadRequestException('العرض غير متاح للقبول', 'Offer not available');

      const [ride] = await queryRaw<any[]>(tx)`
        SELECT * FROM rides WHERE id = ${offerRef.ride_id} FOR UPDATE`;
      if (!ride || ride.status !== 'SEARCHING' || ride.driver_id !== null) {
        throw new ConflictException('الرحلة لم تعد متاحة للإسناد', 'Ride is no longer assignable');
      }

      const [offer] = await queryRaw<any[]>(tx)`
        SELECT * FROM ride_offers
        WHERE id = ${params.offerId} AND driver_id = ${params.driverId}
        FOR UPDATE`;
      if (!offer || offer.status !== 'PENDING') {
        throw new BadRequestException('العرض غير متاح للقبول', 'Offer not available');
      }
      const now = new Date();
      if (now >= new Date(offer.expires_at)) {
        throw new BadRequestException('العرض منتهي الصلاحية', 'Offer expired');
      }

      // Serialize all acceptances by the same driver, even across different rides.
      const [driverRow] = await queryRaw<any[]>(tx)`
        SELECT dp.verification_status, dp.is_online, dp.service_area_id, u.status
        FROM driver_profiles dp
        JOIN users u ON u.id = dp.user_id
        WHERE dp.user_id = ${params.driverId}
        FOR UPDATE OF dp`;
      if (!driverRow) throw new BadRequestException('ملف السائق غير موجود', 'Driver profile not found');
      const d = driverRow;
      if (d.verification_status !== 'APPROVED') throw new BadRequestException('السائق غير معتمد', 'Driver not verified');
      if (d.is_online !== true) throw new BadRequestException('السائق غير متصل', 'Driver not online');
      if (d.status !== 'ACTIVE') throw new BadRequestException('حساب السائق غير نشط', 'User not active');
      if (d.service_area_id !== ride.service_area_id) {
        throw new BadRequestException('السائق خارج منطقة خدمة الرحلة', 'Driver outside ride service area');
      }

      const activeRides = await queryRaw<Array<{ id: string }>>(tx)`
        SELECT id FROM rides
        WHERE driver_id = ${params.driverId}
          AND status IN ('ASSIGNED','ARRIVING','ARRIVED','IN_PROGRESS')
        LIMIT 1`;
      if (activeRides.length > 0) {
        throw new ConflictException('لدى السائق رحلة نشطة بالفعل', 'Driver already has an active ride');
      }

      const [vehicle] = await queryRaw<any[]>(tx)`
        SELECT id FROM vehicles
        WHERE id = ${params.vehicleId}
          AND driver_id = ${params.driverId}
          AND vehicle_type_id = ${ride.vehicle_type_id}
          AND is_active = true
        FOR UPDATE`;
      if (!vehicle) throw new BadRequestException('المركبة غير صالحة لهذا السائق أو الرحلة', 'Vehicle is not active or does not belong to this driver');

      const settings = await tx.dispatchSettings.findUnique({ where: { serviceAreaId: ride.service_area_id } });
      const ttlMinutes = Number(settings?.startCodeTtlMinutes ?? 15);
      const nonce = newStartCodeNonce();
      const startCodeExpiresAt = new Date(now.getTime() + ttlMinutes * 60 * 1000);

      const [assigned] = await queryRaw<any[]>(tx)`
        UPDATE rides
        SET status = 'ASSIGNED',
            driver_id = ${params.driverId},
            vehicle_id = ${params.vehicleId},
            assigned_at = ${now},
            start_code_nonce = ${nonce},
            start_code_expires_at = ${startCodeExpiresAt},
            version = version + 1
        WHERE id = ${offer.ride_id}
          AND status = 'SEARCHING'
          AND driver_id IS NULL
        RETURNING *`;
      if (!assigned) throw new ConflictException('تم إسناد الرحلة لسائق آخر بالفعل', 'Ride already assigned');

      await tx.rideOffers.update({
        where: { id: params.offerId },
        data: { status: 'ACCEPTED', respondedAt: now },
      });
      await tx.rideOffers.updateMany({
        where: { rideId: offer.ride_id, id: { not: params.offerId }, status: 'PENDING' },
        data: { status: 'CANCELLED', respondedAt: now },
      });
      await tx.rideEvents.create({
        data: {
          rideId: offer.ride_id,
          eventType: 'DRIVER_ASSIGNED',
          fromStatus: 'SEARCHING',
          toStatus: 'ASSIGNED',
          actorRole: 'SYSTEM',
          actorUserId: params.driverId,
          payload: {},
        },
      });
      return { ride: assigned, offer: { ...offer, status: 'ACCEPTED', responded_at: now } };
    });
  }

  async sweep() {
    const now = new Date();
    await this.prisma.rideOffers.updateMany({
      where: { status: 'PENDING', expiresAt: { lt: now } },
      data: { status: 'EXPIRED', respondedAt: now },
    });
    await this.prisma.rides.updateMany({
      where: { status: 'SEARCHING', searchExpiresAt: { lt: now } },
      data: { status: 'NO_DRIVER_FOUND' },
    });
    return { ok: true };
  }
}
