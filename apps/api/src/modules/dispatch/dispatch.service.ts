import { Injectable, NotFoundException, BadRequestException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { transition, type RideSnapshot, type Actor } from '../../domain/ride-state.js';
import { newStartCodeNonce } from '../../domain/start-code.js';

// Keep row typing local without passing a generic to Prisma's generated raw-query method.
const queryRaw = <T>(tx: any) =>
  (strings: TemplateStringsArray, ...values: any[]): Promise<T> =>
    tx.$queryRaw(strings, ...values) as Promise<T>;

/** Upper bound on rides transitioned per sweep, to keep the transaction short. */
const SEARCH_EXPIRY_BATCH = 500;

@Injectable()
export class DispatchService {
  constructor(private prisma: PrismaService) {}

  async search(ride_id: string) {
    return this.prisma.tx(async (tx) => {
      const [ride] = await queryRaw<any[]>(tx)`SELECT * FROM rides WHERE id = ${ride_id} FOR UPDATE`;
      if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
      if (ride.status !== 'SEARCHING' || ride.driver_id !== null) {
        throw new BadRequestException('الرحلة ليست في حالة بحث', 'Ride is not searching');
      }

      // Concurrent/retried search calls for the same ride serialize on the ride
      // row. Return existing live offers rather than creating duplicate batches.
      const existing = await tx.ride_offers.findMany({
        where: { ride_id, status: 'PENDING', expires_at: { gt: new Date() } },
        orderBy: { offered_at: 'asc' },
      });
      if (existing.length > 0) {
        return { ride_id, offers: existing, expires_at: existing.reduce((latest, o) => o.expires_at > latest ? o.expires_at : latest, existing[0].expires_at), replayed: true };
      }
      await tx.ride_offers.updateMany({
        where: { ride_id, status: 'PENDING', expires_at: { lte: new Date() } },
        data: { status: 'EXPIRED', responded_at: new Date() },
      });

      const settings = await tx.dispatch_settings.findUnique({ where: { service_area_id: ride.service_area_id } });
      if (!settings) throw new BadRequestException('لا توجد إعدادات إسناد لهذه المنطقة', 'No dispatch settings for area');

      const [pickup] = await queryRaw<Array<{ lon: number; lat: number }>>(tx)`
        SELECT ST_X(pickup::geometry) AS lon, ST_Y(pickup::geometry) AS lat
        FROM rides WHERE id = ${ride_id}`;
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
          AND dp.last_location_at > now() - (${settings.location_max_age_seconds} * interval '1 second')
          AND NOT EXISTS (
            SELECT 1 FROM rides r
            WHERE r.driver_id = dp.user_id
              AND r.status IN ('ASSIGNED','ARRIVING','ARRIVED','IN_PROGRESS')
          )
          AND NOT EXISTS (
            SELECT 1 FROM ride_offers ro
            WHERE ro.ride_id = ${ride_id}
              AND ro.driver_id = dp.user_id
              AND ro.status = 'PENDING'
              AND ro.expires_at > now()
          )
          AND ST_DWithin(dp.last_location,
            ST_SetSRID(ST_MakePoint(${pickupLon}, ${pickupLat})::geometry, 4326)::geography, ${settings.search_radius_m})
        ORDER BY distance_m
        LIMIT ${settings.max_candidates}`;

      const batch = candidates.slice(0, settings.offer_batch_size);
      if (batch.length === 0) return { ride_id, offers: [], expires_at: null, replayed: false };

      const priorRound = await tx.ride_offers.aggregate({ where: { ride_id }, _max: { round_no: true } });
      const round_no = (priorRound._max.round_no ?? 0) + 1;
      const expires_at = new Date(Date.now() + settings.offer_ttl_seconds * 1000);
      const offers = await Promise.all(batch.map((candidate) => tx.ride_offers.create({
        data: {
          ride_id,
          driver_id: candidate.driver_id,
          round_no,
          distance_to_pickup_m: Number(candidate.distance_m ?? 0),
          expires_at,
        },
      })));
      return { ride_id, offers, expires_at, replayed: false };
    });
  }

  async acceptOffer(params: { offerId: string; driver_id: string; vehicle_id: string }) {
    return this.prisma.tx(async (tx) => {
      // Discover the ride id without locking the offer, then always lock in the
      // same order: ride -> offer -> driver. This avoids the deadlock where two
      // acceptors each lock a different offer and then cancel each other's row.
      const [offerRef] = await queryRaw<Array<{ ride_id: string }>>(tx)`
        SELECT ride_id FROM ride_offers WHERE id = ${params.offerId} AND driver_id = ${params.driver_id}`;
      if (!offerRef) throw new BadRequestException('العرض غير متاح للقبول', 'Offer not available');

      const [ride] = await queryRaw<any[]>(tx)`
        SELECT * FROM rides WHERE id = ${offerRef.ride_id} FOR UPDATE`;
      if (!ride || ride.status !== 'SEARCHING' || ride.driver_id !== null) {
        throw new ConflictException('الرحلة لم تعد متاحة للإسناد', 'Ride is no longer assignable');
      }

      const [offer] = await queryRaw<any[]>(tx)`
        SELECT * FROM ride_offers
        WHERE id = ${params.offerId} AND driver_id = ${params.driver_id}
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
        WHERE dp.user_id = ${params.driver_id}
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
        WHERE driver_id = ${params.driver_id}
          AND status IN ('ASSIGNED','ARRIVING','ARRIVED','IN_PROGRESS')
        LIMIT 1`;
      if (activeRides.length > 0) {
        throw new ConflictException('لدى السائق رحلة نشطة بالفعل', 'Driver already has an active ride');
      }

      const [vehicle] = await queryRaw<any[]>(tx)`
        SELECT id FROM vehicles
        WHERE id = ${params.vehicle_id}
          AND driver_id = ${params.driver_id}
          AND vehicle_type_id = ${ride.vehicle_type_id}
          AND is_active = true
        FOR UPDATE`;
      if (!vehicle) throw new BadRequestException('المركبة غير صالحة لهذا السائق أو الرحلة', 'Vehicle is not active or does not belong to this driver');

      const settings = await tx.dispatch_settings.findUnique({ where: { service_area_id: ride.service_area_id } });
      const ttlMinutes = Number(settings?.start_code_ttl_minutes ?? 15);
      const nonce = newStartCodeNonce();
      const start_code_expires_at = new Date(now.getTime() + ttlMinutes * 60 * 1000);

      const [assigned] = await queryRaw<any[]>(tx)`
        UPDATE rides
        SET status = 'ASSIGNED',
            driver_id = ${params.driver_id},
            vehicle_id = ${params.vehicle_id},
            assigned_at = ${now},
            start_code_nonce = ${nonce},
            start_code_expires_at = ${start_code_expires_at},
            version = version + 1
        WHERE id = ${offer.ride_id}
          AND status = 'SEARCHING'
          AND driver_id IS NULL
        RETURNING *`;
      if (!assigned) throw new ConflictException('تم إسناد الرحلة لسائق آخر بالفعل', 'Ride already assigned');

      await tx.ride_offers.update({
        where: { id: params.offerId },
        data: { status: 'ACCEPTED', responded_at: now },
      });
      await tx.ride_offers.updateMany({
        where: { ride_id: offer.ride_id, id: { not: params.offerId }, status: 'PENDING' },
        data: { status: 'CANCELLED', responded_at: now },
      });
      await tx.ride_events.create({
        data: {
          ride_id: offer.ride_id,
          event_type: 'DRIVER_ASSIGNED',
          from_status: 'SEARCHING',
          to_status: 'ASSIGNED',
          actor_role: 'SYSTEM',
          actor_user_id: params.driver_id,
          payload: {},
        },
      });
      return { ride: assigned, offer: { ...offer, status: 'ACCEPTED', responded_at: now } };
    });
  }

  /**
   * Expire timed-out offers and searches.
   *
   * Driven by [DispatchSweeperService] on an interval; also exposed to staff as
   * `POST /dispatch/sweep` for manual recovery. Must stay idempotent and behave
   * under concurrency, because every API replica runs its own sweeper.
   */
  async sweep() {
    const now = new Date();

    // Offer expiry changes no ride state, so one conditional update suffices and
    // a replica that loses the race simply matches zero rows.
    const { count: expiredOffers } = await this.prisma.ride_offers.updateMany({
      where: { status: 'PENDING', expires_at: { lt: now } },
      data: { status: 'EXPIRED', responded_at: now },
    });

    // Search expiry goes through the domain state machine and leaves an audit
    // row. A bare `updateMany` would flip the ride to NO_DRIVER_FOUND with no
    // ride_events record, so neither the audit trail nor the rider's client
    // would ever learn that the search had ended.
    const searchesExpired = await this.prisma.tx(async (tx) => {
      const expired = await queryRaw<
        Array<{ id: string; customer_id: string; driver_id: string | null }>
      >(tx)`
        SELECT id, customer_id, driver_id
        FROM rides
        WHERE status = 'SEARCHING' AND search_expires_at < ${now}
        ORDER BY search_expires_at
        LIMIT ${SEARCH_EXPIRY_BATCH}
        FOR UPDATE SKIP LOCKED`;

      let applied = 0;
      for (const ride of expired) {
        const result = transition(
          { status: 'SEARCHING', customer_id: ride.customer_id, driver_id: ride.driver_id },
          'SEARCH_EXPIRED',
          { role: 'SYSTEM' },
        );

        const updated = await queryRaw<Array<{ id: string }>>(tx)`
          UPDATE rides SET status = ${result.to}
          WHERE id = ${ride.id} AND status = 'SEARCHING'
          RETURNING id`;
        if (updated.length === 0) continue;

        await tx.ride_events.create({
          data: {
            ride_id: ride.id,
            event_type: 'SEARCH_EXPIRED',
            from_status: 'SEARCHING',
            to_status: result.to,
            actor_role: 'SYSTEM',
            payload: {},
          },
        });
        applied += 1;
      }
      return applied;
    });

    return { ok: true, expiredOffers, searchesExpired };
  }
}
