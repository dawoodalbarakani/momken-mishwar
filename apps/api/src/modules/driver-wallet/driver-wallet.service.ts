import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { buildCashRideEntries, type CashRideSettlementInput } from '../../domain/ledger.js';

@Injectable()
export class DriverWalletService {
  constructor(private prisma: PrismaService) {}

  async balance(driverId: string, currency = 'YER') {
    const entries = await this.prisma.driverLedgerEntries.findMany({ where: { driverId, currencyCode: currency } });
    let sum = 0;
    for (const e of entries) sum += Number(e.amount);
    return { driverId, currency, balanceMinor: sum };
  }

  async ledger(driverId: string, limit = 50) {
    return this.prisma.driverLedgerEntries.findMany({
      where: { driverId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 100),
    });
  }

  async settleCashRide(params: { rideId: string; driverId: string; currency: string; grossMinor: number; commissionMinor: number; driverNetMinor: number; idempotencyKey: string }) {
    const input: CashRideSettlementInput = {
      rideId: params.rideId,
      driverId: params.driverId,
      currency: params.currency,
      grossMinor: params.grossMinor,
      commissionMinor: params.commissionMinor,
      driverNetMinor: params.driverNetMinor,
    };
    const drafts = buildCashRideEntries(input);
    return this.prisma.$transaction(
      drafts.map((d) =>
        this.prisma.driverLedgerEntries.create({
          data: {
            driverId: d.driverId,
            rideId: d.rideId,
            entryType: d.entryType,
            amount: d.amountMinor / 100,
            currencyCode: d.currency,
            idempotencyKey: d.idempotencyKey,
            memo: d.memo ?? null,
          },
        }),
      ),
    );
  }

  async requestPayout(params: { driverId: string; amount: number; currencyCode: string; requestedBy: string; method?: string; reference?: string; note?: string }) {
    return this.prisma.driverPayouts.create({
      data: {
        driverId: params.driverId,
        direction: 'PLATFORM_TO_DRIVER',
        amount: params.amount,
        currencyCode: params.currencyCode,
        status: 'PENDING',
        method: params.method ?? null,
        reference: params.reference ?? null,
        note: params.note ?? null,
        requestedBy: params.requestedBy,
        reviewedBy: null,
      },
    });
  }
}
