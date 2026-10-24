import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class PaymentsService {
  constructor(private prisma: PrismaService) {}

  async createForRide(params: { rideId: string; amount: number; currencyCode: string; method: 'CASH' }) {
    const ride = await this.prisma.rides.findUnique({ where: { id: params.rideId } });
    if (!ride) throw new NotFoundException('الرحلة غير موجودة', 'Ride not found');
    if (params.method !== 'CASH') throw new BadRequestException('وسيلة الدفع المدعومة حاليا هي النقد فقط', 'Only CASH supported in v1');
    return this.prisma.paymentRecords.create({
      data: { rideId: params.rideId, method: 'CASH', status: 'PENDING', amount: params.amount, currencyCode: params.currencyCode },
    });
  }

  async list(query: { status?: string; limit?: number }) {
    return this.prisma.paymentRecords.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { createdAt: 'desc' },
      take: Math.min(query.limit ?? 50, 100),
    });
  }
}
