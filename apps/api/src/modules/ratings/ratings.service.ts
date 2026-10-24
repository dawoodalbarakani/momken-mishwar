import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class RatingsService {
  constructor(private prisma: PrismaService) {}

  async create(params: { rideId: string; raterId: string; rateeId: string; raterRole: string; score: number; comment?: string }) {
    return this.prisma.ratings.create({ data: params });
  }

  async listForRatee(rateeId: string) {
    return this.prisma.ratings.findMany({ where: { rateeId }, orderBy: { createdAt: 'desc' } });
  }
}
