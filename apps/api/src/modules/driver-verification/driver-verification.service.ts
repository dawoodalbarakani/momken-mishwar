import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

export type VerificationStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED';

@Injectable()
export class DriverVerificationService {
  constructor(private prisma: PrismaService) {}

  async review(params: {
    driverId: string;
    status: VerificationStatus;
    reviewedBy: string;
    note?: string;
    rejectionReason?: string;
  }) {
    const data: any = {
      verificationStatus: params.status,
      verificationReviewedBy: params.reviewedBy,
      verificationReviewedAt: new Date(),
      verificationNote: params.note ?? null,
      suspensionReason: params.status === 'SUSPENDED' ? (params.rejectionReason ?? null) : null,
    };
    return this.prisma.driverProfiles.update({ where: { userId: params.driverId }, data });
  }

  async getStatus(driverId: string) {
    const profile = await this.prisma.driverProfiles.findUnique({ where: { userId: driverId } });
    if (!profile) throw new NotFoundException('ملف السائق غير موجود', 'Driver profile not found');
    return { verificationStatus: profile.verificationStatus };
  }
}
