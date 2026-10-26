import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { computePrice, type PricingRule, type QuoteInput } from '../../domain/pricing.js';

@Injectable()
export class PricingService {
  constructor(private prisma: PrismaService) {}

  async quote(params: {
    pickupLat: number;
    pickupLon: number;
    destLat: number;
    destLon: number;
    service_area_id?: string;
    vehicle_type_id?: string;
  }) {
    const rule = await this.prisma.pricing_rules.findFirst({
      where: {
        status: 'ACTIVE',
        ...(params.service_area_id ? { service_area_id: params.service_area_id } : {}),
        ...(params.vehicle_type_id ? { vehicle_type_id: params.vehicle_type_id } : {}),
      },
      orderBy: { version: 'desc' },
    });
    if (!rule) {
      throw new NotFoundException('لا توجد قاعدة تسعير فعالة', 'No active pricing rule');
    }

    // Distance between pickup and destination via PostGIS (geography, meters).
    const [distRow] = (await this.prisma.$queryRaw`
      SELECT ST_Distance(
        ST_SetSRID(ST_MakePoint(${params.pickupLon}, ${params.pickupLat})::geometry, 4326)::geography,
        ST_SetSRID(ST_MakePoint(${params.destLon}, ${params.destLat})::geometry, 4326)::geography
      ) AS distance_m` as any[]);
    const distanceMeters = Number(distRow?.distance_m ?? 0);
    const durationSeconds = Math.ceil(distanceMeters / 5); // rough 5 m/s estimate

    const domainRule: PricingRule = {
      id: rule.id,
      version: rule.version,
      mode: rule.mode as any,
      currency: rule.currency_code,
      baseFareMinor: Number(rule.base_fare) * 100,
      perKmMinor: Number(rule.per_km) * 100,
      perMinuteMinor: Number(rule.per_minute) * 100,
      minimumFareMinor: Number(rule.minimum_fare) * 100,
      surcharges: (rule.surcharges as any[]) ?? [],
      commission_bps: rule.commission_bps,
      roundingStepMinor: Number(rule.rounding_step) * 100,
    };

    const input: QuoteInput = { distanceMeters, durationSeconds };
    const breakdown = computePrice(domainRule, input);
    return { ...breakdown, ruleVersion: breakdown.ruleVersion, estimated: true };
  }

  async listRules(service_area_id?: string) {
    return this.prisma.pricing_rules.findMany({
      where: service_area_id ? { service_area_id, status: 'ACTIVE' } : { status: 'ACTIVE' },
      orderBy: [{ service_area_id: 'asc' }, { version: 'desc' }],
    });
  }
}
