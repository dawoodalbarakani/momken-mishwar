import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class AdminService {
  constructor(private prisma: PrismaService) {}

  async listDrivers(query: { status?: string; limit?: number }) {
    return this.prisma.driverProfiles.findMany({
      where: query.status ? { verificationStatus: query.status } : {},
      include: { user: true },
      take: Math.min(query.limit ?? 50, 100),
    });
  }

  async listRides(query: { status?: string; limit?: number }) {
    return this.prisma.rides.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { requestedAt: 'desc' },
      take: Math.min(query.limit ?? 50, 100),
    });
  }

  async cancelRide(rideId: string, reason: string, staffId: string) {
    const ride = await this.prisma.rides.findUnique({ where: { id: rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    return this.prisma.rides.update({
      where: { id: rideId },
      data: { status: 'CANCELLED', cancelledByRole: 'STAFF', cancelledByUserId: staffId, cancelReasonCode: reason, cancelledAt: new Date() },
    });
  }

  async listPricingRules(query: { serviceAreaId?: string }) {
    return this.prisma.pricingRules.findMany({
      where: query.serviceAreaId ? { serviceAreaId: query.serviceAreaId } : {},
      orderBy: [{ serviceAreaId: 'asc' }, { version: 'desc' }],
      take: 100,
    });
  }

  async listPayouts(query: { status?: string; limit?: number }) {
    return this.prisma.driverPayouts.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { createdAt: 'desc' },
      take: Math.min(query.limit ?? 50, 100),
    });
  }

  async approvePayout(payoutId: string, reviewerId: string) {
    const payout = await this.prisma.driverPayouts.findUnique({ where: { id: payoutId } });
    if (!payout) throw new NotFoundException('التسوية غير موجودة', 'Payout not found');
    if (payout.requestedBy === reviewerId) throw new Error('FOUR_EYES');
    return this.prisma.driverPayouts.update({
      where: { id: payoutId },
      data: { status: 'APPROVED', reviewedBy: reviewerId, reviewedAt: new Date() },
    });
  }

  async driverBalances() {
    return this.prisma.$queryRaw`SELECT driver_id, currency_code, balance, entry_count FROM driver_balances ORDER BY driver_id`;
  }
}
