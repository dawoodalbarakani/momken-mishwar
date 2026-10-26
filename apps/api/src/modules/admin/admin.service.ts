import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  async listDrivers(query: { status?: string; limit?: number }) {
    return this.prisma.driver_profiles.findMany({
      where: query.status ? { verification_status: query.status } : {},
      take: Math.min(query.limit ?? 50, 100),
    });
  }

  async listRides(query: { status?: string; limit?: number }) {
    return this.prisma.rides.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { requested_at: 'desc' },
      take: Math.min(query.limit ?? 50, 100),
    });
  }

  async cancelRide(ride_id: string, reason: string, staffId: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: ride_id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    return this.prisma.rides.update({
      where: { id: ride_id },
      data: { status: 'CANCELLED', cancelled_by_role: 'STAFF', cancelled_by_user_id: staffId, cancel_reason_code: reason, cancelled_at: new Date() },
    });
  }

  async listPricingRules(query: { service_area_id?: string }) {
    return this.prisma.pricing_rules.findMany({
      where: query.service_area_id ? { service_area_id: query.service_area_id } : {},
      orderBy: [{ service_area_id: 'asc' }, { version: 'desc' }],
      take: 100,
    });
  }

  async listPayouts(query: { status?: string; limit?: number }) {
    return this.prisma.driver_payouts.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { created_at: 'desc' },
      take: Math.min(query.limit ?? 50, 100),
    });
  }

  async approvePayout(payoutId: string, reviewerId: string) {
    const payout = await this.prisma.driver_payouts.findUnique({ where: { id: payoutId } });
    if (!payout) throw new NotFoundException('التسوية غير موجودة', 'Payout not found');
    if (payout.requested_by === reviewerId) throw new Error('FOUR_EYES');
    return this.prisma.driver_payouts.update({
      where: { id: payoutId },
      data: { status: 'APPROVED', reviewedBy: reviewerId, reviewedAt: new Date() },
    });
  }

  async driverBalances() {
    return this.prisma.$queryRaw`SELECT driver_id, currency_code, balance, entry_count FROM driver_balances ORDER BY driver_id`;
  }

  async stats() {
    const [rideStats, driverStats, payoutStats] = await Promise.all([
      this.prisma.$queryRaw`SELECT status, count(*) AS count FROM rides GROUP BY status`,
      this.prisma.$queryRaw`SELECT count(*) AS count FROM driver_profiles WHERE is_online = true`,
      this.prisma.$queryRaw`SELECT sum(amount) AS total FROM driver_payouts WHERE status = 'APPROVED'`,
    ]);

    const tripsByStatus: Record<string, number> = {};
    let totalRides = 0;
    for (const row of rideStats as any[]) {
      tripsByStatus[row.status] = Number(row.count);
      totalRides += Number(row.count);
    }

    return {
      tripsByStatus,
      totalRides,
      onlineDrivers: Number((driverStats as any[])[0]?.count ?? 0),
      totalPaidOutMinor: Number((payoutStats as any[])[0]?.total ?? 0),
    };
  }
}
