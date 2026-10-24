import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class DriverLocationsService {
  constructor(private prisma: PrismaService) {}

  async updateBatch(params: { driverId: string; updates: Array<{ lat: number; lon: number; accuracyM?: number; speedMps?: number; headingDeg?: number; recordedAt: string; rideId?: string }> }) {
    const driver = await this.prisma.driverProfiles.findUnique({ where: { userId: params.driverId } });
    if (!driver) throw new NotFoundException('ملف السائق غير موجود', 'Driver profile not found');

    const last = params.updates[params.updates.length - 1];
    await this.prisma.driverProfiles.update({
      where: { userId: params.driverId },
      data: {
        lastLocation: last as any,
        lastLocationAt: new Date(last.recordedAt),
        lastLocationAccuracyM: last.accuracyM ?? null,
      },
    });

    const rows = params.updates.map((u) => `(${params.driverId}, ${u.rideId ?? 'NULL'}, ST_SetSRID(ST_MakePoint(${u.lon}, ${u.lat})::geometry,4326)::geography, ${u.accuracyM ?? 'NULL'}, ${u.speedMps ?? 'NULL'}, ${u.headingDeg ?? 'NULL'}, '${u.recordedAt}', now())`);
    if (rows.length) {
      await this.prisma.$executeRaw`INSERT INTO driver_location_updates (driver_id, ride_id, location, accuracy_m, speed_mps, heading_deg, recorded_at, received_at) VALUES ${rows.join(',')}`;
    }
    return { ok: true, count: params.updates.length };
  }

  async latest(driverId: string) {
    const row = await this.prisma.$queryRaw`
      SELECT location, last_location_at AS updated_at FROM driver_profiles WHERE user_id = ${driverId}`;
    const r = (row as any[])[0];
    const ageMs = r?.updated_at ? Date.now() - new Date(r.updated_at).getTime() : null;
    return { location: r?.location ?? null, updatedAt: r?.updated_at ?? null, ageSec: ageMs ? Math.floor(ageMs / 1000) : null };
  }
}
