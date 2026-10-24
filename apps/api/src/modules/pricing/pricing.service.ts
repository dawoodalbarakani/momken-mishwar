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
    serviceAreaId?: string;
    vehicleTypeId?: string;
  }) {
    const rule = await this.prisma.pricingRules.findFirst({
      where: {
        status: 'ACTIVE',
        ...(params.serviceAreaId ? { serviceAreaId: params.serviceAreaId } : {}),
        ...(params.vehicleTypeId ? { vehicleTypeId: params.vehicleTypeId } : {}),
      },
      orderBy: { version: 'desc' },
    });
    if (!rule) {
      throw new NotFoundException('لا توجد قاعدة تسعير فعالة', 'No active pricing rule');
    }

    // Distance between pickup and destination via PostGIS (geography, meters).
    const [distRow] = await this.prisma.$queryRaw`
      SELECT ST_Distance(
        ST_SetSRID(ST_MakePoint(${params.pickupLon}, ${params.pickupLat})::geometry, 4326)::geography,
        ST_SetSRID(ST_MakePoint(${params.destLon}, ${params.destLat})::geometry, 4326)::geography
      ) AS distance_m`;
    const distanceMeters = Number(distRow?.distance_m ?? 0);
    const durationSeconds = Math.ceil(distanceMeters / 5); // rough 5 m/s estimate

    const domainRule: PricingRule = {
      id: rule.id,
      version: rule.version,
      mode: rule.mode as any,
      currency: rule.currencyCode,
      baseFareMinor: Number(rule.baseFare) * 100,
      perKmMinor: Number(rule.perKm) * 100,
      perMinuteMinor: Number(rule.perMinute) * 100,
      minimumFareMinor: Number(rule.minimumFare) * 100,
      surcharges: (rule.surcharges as any[]) ?? [],
      commissionBps: rule.commissionBps,
      roundingStepMinor: Number(rule.roundingStep) * 100,
    };

    const input: QuoteInput = { distanceMeters, durationSeconds };
    const breakdown = computePrice(domainRule, input);
    return { ...breakdown, ruleVersion: breakdown.ruleVersion, estimated: true };
  }

  async listRules(serviceAreaId?: string) {
    return this.prisma.pricingRules.findMany({
      where: serviceAreaId ? { serviceAreaId, status: 'ACTIVE' } : { status: 'ACTIVE' },
      orderBy: [{ serviceAreaId: 'asc' }, { version: 'desc' }],
    });
  }
}
