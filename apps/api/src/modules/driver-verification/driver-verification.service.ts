import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

export type VerificationStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED';

@Injectable()
export class DriverVerificationService {
  constructor(private prisma: PrismaService) {}

  async review(params: {
    driver_id: string;
    status: VerificationStatus;
    reviewedBy: string;
    note?: string;
    rejection_reason?: string;
  }) {
    const data: any = {
      verification_status: params.status,
      verification_reviewed_by: params.reviewedBy,
      verification_reviewed_at: new Date(),
      verificationNote: params.note ?? null,
      suspensionReason: params.status === 'SUSPENDED' ? (params.rejection_reason ?? null) : null,
    };
    return this.prisma.driver_profiles.update({ where: { user_id: params.driver_id }, data });
  }

  async getStatus(driver_id: string) {
    const profile = await this.prisma.driver_profiles.findUnique({ where: { user_id: driver_id } });
    if (!profile) throw new NotFoundException('ملف السائق غير موجود', 'Driver profile not found');
    return { verification_status: profile.verification_status };
  }
}
