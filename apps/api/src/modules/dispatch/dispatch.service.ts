import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { transition, type RideSnapshot, type Actor } from '../../domain/ride-state.js';
import { newStartCodeNonce } from '../../domain/start-code.js';

@Injectable()
export class DispatchService {
  constructor(private prisma: PrismaService) {}

  async search(rideId: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (ride.status !== 'SEARCHING') throw new BadRequestException('الرحلة ليست في حالة بحث', 'Ride is not searching');

    const settings = await this.prisma.dispatchSettings.findUnique({ where: { serviceAreaId: ride.serviceAreaId } });
    if (!settings) throw new BadRequestException('لا توجد إعدادات.dispatch لهذه المنطقة', 'No dispatch settings for area');

    const [{ lon, lat }] = await this.prisma.$queryRaw`
      SELECT ST_X(pickup::geometry) AS lon, ST_Y(pickup::geometry) AS lat
      FROM rides WHERE id = ${rideId}`;
    const pickupLon = Number(lon);
    const pickupLat = Number(lat);

    const candidates = await this.prisma.$queryRaw`
      SELECT dp.user_id AS driver_id,
             ST_Distance(dp.last_location,
               ST_SetSRID(ST_MakePoint(${pickupLon}, ${pickupLat})::geometry, 4326)::geography) AS distance_m
      FROM driver_profiles dp
      JOIN users u ON u.id = dp.user_id
      WHERE dp.is_online = true
        AND dp.verification_status = 'APPROVED'
        AND dp.last_location IS NOT NULL
        AND dp.last_location_at > now() - interval '${settings.locationMaxAgeSeconds} seconds'
        AND NOT EXISTS (
          SELECT 1 FROM rides r
          WHERE r.driver_id = dp.user_id
            AND r.status IN ('ASSIGNED','ARRIVING','ARRIVED','IN_PROGRESS')
        )
        AND ST_DWithin(dp.last_location,
          ST_SetSRID(ST_MakePoint(${pickupLon}, ${pickupLat})::geometry, 4326)::geography, ${settings.searchRadiusM})
      ORDER BY distance_m
      LIMIT ${settings.maxCandidates}`;

    const batch = (candidates as any[]).slice(0, settings.offerBatchSize);
    const expiresAt = new Date(Date.now() + settings.offerTtlSeconds * 1000);

    const offers = await this.prisma.$transaction(
      batch.map((c) =>
        this.prisma.rideOffers.create({
          data: {
            rideId,
            driverId: c.driver_id,
            roundNo: 1,
            distanceToPickupM: Number(c.distance_m ?? 0),
            expiresAt,
          },
        }),
      ),
    );

    return { rideId, offers, expiresAt };
  }

  async acceptOffer(params: { offerId: string; driverId: string; vehicleId: string }) {
    return this.prisma.tx(async (tx) => {
      // 1. قفل العرض FOR UPDATE والتأكد من حالته وصلاحيته.
      const [offer] = await tx.$queryRaw`SELECT * FROM ride_offers WHERE id = ${params.offerId} AND driver_id = ${params.driverId} FOR UPDATE`;
      if (!offer || (offer as any).status !== 'PENDING') {
        throw new BadRequestException('العرض غير متاح للقبول', 'Offer not available');
      }
      if (new Date() >= (offer as any).expires_at) {
        throw new BadRequestException('العرض منتهي الصلاحية', 'Offer expired');
      }

      const rideId = (offer as any).ride_id;

      const ride = await tx.rides.findUnique({ where: { id: rideId } });
      if (!ride || ride.status !== 'SEARCHING') {
        throw new BadRequestException('الرحلة غير متاحة للإسناد', 'Ride not assignable');
      }

      // 2. قفل صف السائق FOR SHARE والتحقق من الأهلية ومنطقة الخدمة.
      const [driverRow] = await tx.$queryRaw`
        SELECT dp.verification_status, dp.is_online, dp.service_area_id, u.status
        FROM driver_profiles dp
        JOIN users u ON u.id = dp.user_id
        WHERE dp.user_id = ${params.driverId}
        FOR SHARE OF dp`;
      if (!driverRow) {
        throw new BadRequestException('ملف السائق غير موجود', 'Driver profile not found');
      }
      const d = driverRow as any;
      if (d.verification_status !== 'APPROVED') throw new BadRequestException('السائق غير معتمد', 'Driver not verified');
      if (d.is_online !== true) throw new BadRequestException('السائق غير متصل', 'Driver not online');
      if (d.status !== 'ACTIVE') throw new BadRequestException('حساب السائق غير نشط', 'User not active');
      if (d.service_area_id !== ride.serviceAreaId) {
        throw new BadRequestException('السائق خارج منطقة خدمة الرحلة', 'Driver outside ride service area');
      }

      // 4. إنشاء start_code_nonce وانتهاء صلاحيته من إعدادات الإسناد.
      const settings = await tx.dispatchSettings.findUnique({ where: { serviceAreaId: ride.serviceAreaId } });
      const ttlMinutes = Number(settings?.startCodeTtlMinutes ?? 15);
      const nonce = newStartCodeNonce();
      const now = new Date();
      const startCodeExpiresAt = new Date(now.getTime() + ttlMinutes * 60 * 1000);

      // 3. تحديث شرطي على الرحلة: إسناد سائق واحد فقط عندما تكون SEARCHING وبدون سائق.
      const [assigned] = await tx.$queryRaw`
        UPDATE rides
        SET status = 'ASSIGNED',
            driver_id = ${params.driverId},
            vehicle_id = ${params.vehicleId},
            assigned_at = now(),
            start_code_nonce = ${nonce},
            start_code_expires_at = ${startCodeExpiresAt},
            version = version + 1
        WHERE id = ${rideId}
          AND status = 'SEARCHING'
          AND driver_id IS NULL
        RETURNING *`;
      if (!assigned) {
        throw new ConflictException('تم إسناد الرحلة لسائق آخر بالفعل', 'Ride already assigned');
      }

      // 5. قبول العرض وإلغاء العروض المتبقية قيد الانتظار لنفس الرحلة.
      await tx.rideOffers.update({ where: { id: params.offerId }, data: { status: 'ACCEPTED', respondedAt: now } });
      await tx.rideOffers.updateMany({
        where: { rideId, id: { not: params.offerId }, status: 'PENDING' },
        data: { status: 'CANCELLED', respondedAt: now },
      });

      // 6. حدث إسناد السائق.
      await tx.rideEvents.create({
        data: {
          rideId,
          eventType: 'DRIVER_ASSIGNED',
          fromStatus: ride.status,
          toStatus: 'ASSIGNED',
          actorRole: 'SYSTEM',
          actorUserId: params.driverId,
          payload: {},
        },
      });

      return { ride: assigned, offer };
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
