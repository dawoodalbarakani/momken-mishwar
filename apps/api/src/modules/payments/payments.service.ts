import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class PaymentsService {
  constructor(private prisma: PrismaService) {}

  async createForRide(params: { ride_id: string; amount: number; currency_code: string; method: 'CASH' }) {
    const ride = await this.prisma.rides.findUnique({ where: { id: params.ride_id } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (params.method !== 'CASH') throw new BadRequestException('وسيلة الدفع المدعومة حاليا هي النقد فقط', 'Only CASH supported in v1');
    return this.prisma.payment_records.create({
      data: { ride_id: params.ride_id, method: 'CASH', status: 'PENDING', amount: params.amount, currency_code: params.currency_code },
    });
  }

  async list(query: { status?: string; limit?: number }) {
    return this.prisma.payment_records.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { created_at: 'desc' },
      take: Math.min(query.limit ?? 50, 100),
    });
  }
}
