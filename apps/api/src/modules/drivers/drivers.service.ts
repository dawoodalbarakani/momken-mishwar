import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class DriversService {
  constructor(private prisma: PrismaService) {}

  async getProfile(userId: string) {
    const profile = await this.prisma.driverProfiles.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException('ملف السائق غير موجود', 'Driver profile not found');
    return profile;
  }

  async setOnline(userId: string, isOnline: boolean) {
    const profile = await this.getProfile(userId);
    if (isOnline && profile.verificationStatus !== 'APPROVED') {
      throw new ForbiddenException('يجب اعتماد السائق قبل التوفر', 'Driver must be approved to go online');
    }
    return this.prisma.driverProfiles.update({ where: { userId }, data: { isOnline } });
  }

  async list(query: { serviceAreaId?: string; limit?: number }) {
    return this.prisma.driverProfiles.findMany({
      where: query.serviceAreaId ? { serviceAreaId: query.serviceAreaId } : {},
      take: Math.min(query.limit ?? 50, 100),
    });
  }
}
