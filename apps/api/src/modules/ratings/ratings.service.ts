import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class RatingsService {
  constructor(private prisma: PrismaService) {}

  async create(params: { ride_id: string; rater_id: string; ratee_id: string; rater_role: string; score: number; comment?: string }) {
    return this.prisma.ratings.create({ data: params });
  }

  async listForRatee(ratee_id: string) {
    return this.prisma.ratings.findMany({ where: { ratee_id }, orderBy: { created_at: 'desc' } });
  }
}
