import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}

  async getOrCreateProfile(user_id: string) {
    let profile = await this.prisma.customer_profiles.findUnique({ where: { user_id } });
    if (!profile) {
      profile = await this.prisma.customer_profiles.create({ data: { user_id } });
    }
    return profile;
  }

  async listSavedPlaces(customer_id: string) {
    return this.prisma.saved_places.findMany({ where: { customer_id }, orderBy: { created_at: 'desc' } });
  }

  async addSavedPlace(params: { customer_id: string; label: string; address_text?: string }) {
    return (this.prisma.saved_places as any).create({
      data: {
        customer_id: params.customer_id,
        label: params.label,
        address_text: params.address_text ?? null,
      },
    });
  }
}
