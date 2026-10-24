import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}

  async getOrCreateProfile(userId: string) {
    let profile = await this.prisma.customerProfiles.findUnique({ where: { userId } });
    if (!profile) {
      profile = await this.prisma.customerProfiles.create({ data: { userId } });
    }
    return profile;
  }

  async listSavedPlaces(customerId: string) {
    return this.prisma.savedPlaces.findMany({ where: { customerId }, orderBy: { createdAt: 'desc' } });
  }

  async addSavedPlace(params: { customerId: string; label: string; addressText?: string }) {
    return this.prisma.savedPlaces.create({
      data: {
        customerId: params.customerId,
        label: params.label,
        addressText: params.addressText ?? null,
      },
    });
  }
}
