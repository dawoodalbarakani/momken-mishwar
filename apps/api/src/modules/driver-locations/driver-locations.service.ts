import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class DriverLocationsService {
  constructor(private prisma: PrismaService) {}

  async updateBatch(params: { driver_id: string; updates: Array<{ lat: number; lon: number; accuracy_m?: number; speed_mps?: number; heading_deg?: number; recorded_at: string; ride_id?: string }> }) {
    const driver = await this.prisma.driver_profiles.findUnique({ where: { user_id: params.driver_id } });
    if (!driver) throw new NotFoundException('ملف السائق غير موجود', 'Driver profile not found');

    const last = params.updates[params.updates.length - 1];
    await this.prisma.driver_profiles.update({
      where: { user_id: params.driver_id },
      data: {
        last_location: last as any,
        last_location_at: new Date(last.recorded_at),
        last_location_accuracy_m: last.accuracy_m ?? null,
      },
    });

    const rows = params.updates.map((u) => `(${params.driver_id}, ${u.ride_id ?? 'NULL'}, ST_SetSRID(ST_MakePoint(${u.lon}, ${u.lat})::geometry,4326)::geography, ${u.accuracy_m ?? 'NULL'}, ${u.speed_mps ?? 'NULL'}, ${u.heading_deg ?? 'NULL'}, '${u.recorded_at}', now())`);
    if (rows.length) {
      await this.prisma.$executeRaw`INSERT INTO driver_location_updates (driver_id, ride_id, location, accuracy_m, speed_mps, heading_deg, recorded_at, received_at) VALUES ${rows.join(',')}`;
    }
    return { ok: true, count: params.updates.length };
  }

  async latest(driver_id: string) {
    const row = await this.prisma.$queryRaw`
      SELECT location, last_location_at AS updated_at FROM driver_profiles WHERE user_id = ${driver_id}`;
    const r = (row as any[])[0];
    const ageMs = r?.updated_at ? Date.now() - new Date(r.updated_at).getTime() : null;
    return { location: r?.location ?? null, updated_at: r?.updated_at ?? null, ageSec: ageMs ? Math.floor(ageMs / 1000) : null };
  }
}
