import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { buildCashRideEntries, type CashRideSettlementInput } from '../../domain/ledger.js';

@Injectable()
export class DriverWalletService {
  constructor(private prisma: PrismaService) {}

  async balance(driver_id: string, currency = 'YER') {
    const entries = await this.prisma.driver_ledger_entries.findMany({ where: { driver_id, currency_code: currency } });
    let sum = 0;
    for (const e of entries) sum += Number(e.amount);
    return { driver_id, currency, balanceMinor: sum };
  }

  async ledger(driver_id: string, limit = 50) {
    return this.prisma.driver_ledger_entries.findMany({
      where: { driver_id },
      orderBy: { created_at: 'desc' },
      take: Math.min(limit, 100),
    });
  }

  async settleCashRide(params: { ride_id: string; driver_id: string; currency: string; grossMinor: number; commissionMinor: number; driverNetMinor: number; idempotency_key: string }) {
    const input: CashRideSettlementInput = {
      ride_id: params.ride_id,
      driver_id: params.driver_id,
      currency: params.currency,
      grossMinor: params.grossMinor,
      commissionMinor: params.commissionMinor,
      driverNetMinor: params.driverNetMinor,
    };
    const drafts = buildCashRideEntries(input);
    return this.prisma.$transaction(
      drafts.map((d) =>
        this.prisma.driver_ledger_entries.create({
          data: {
            driver_id: d.driver_id,
            ride_id: d.ride_id,
            entry_type: d.entry_type,
            amount: d.amountMinor / 100,
            currency_code: d.currency,
            idempotency_key: d.idempotency_key,
            memo: d.memo ?? null,
          },
        }),
      ),
    );
  }

  async requestPayout(params: { driver_id: string; amount: number; currency_code: string; requested_by: string; method?: string; reference?: string; note?: string }) {
    return this.prisma.driver_payouts.create({
      data: {
        driver_id: params.driver_id,
        direction: 'PLATFORM_TO_DRIVER',
        amount: params.amount,
        currency_code: params.currency_code,
        status: 'PENDING',
        method: params.method ?? null,
        reference: params.reference ?? null,
        note: params.note ?? null,
        requested_by: params.requested_by,
        reviewedBy: null,
      },
    });
  }
}
