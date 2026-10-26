import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class DriversService {
  constructor(private prisma: PrismaService) {}

  async getProfile(user_id: string) {
    const profile = await this.prisma.driver_profiles.findUnique({ where: { user_id } });
    if (!profile) throw new NotFoundException('ملف السائق غير موجود', 'Driver profile not found');
    return profile;
  }

  async setOnline(user_id: string, is_online: boolean) {
    const profile = await this.getProfile(user_id);
    if (is_online && profile.verification_status !== 'APPROVED') {
      throw new ForbiddenException('يجب اعتماد السائق قبل التوفر', 'Driver must be approved to go online');
    }
    return this.prisma.driver_profiles.update({ where: { user_id }, data: { is_online } });
  }

  async list(query: { service_area_id?: string; limit?: number }) {
    return this.prisma.driver_profiles.findMany({
      where: query.service_area_id ? { service_area_id: query.service_area_id } : {},
      take: Math.min(query.limit ?? 50, 100),
    });
  }
}
