import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class VehiclesService {
  constructor(private prisma: PrismaService) {}

  async create(params: { driver_id: string; vehicle_type_id: string; plate_number: string; make?: string; model?: string; year?: number; color?: string }) {
    const driver = await this.prisma.driver_profiles.findUnique({ where: { user_id: params.driver_id } });
    if (!driver) throw new NotFoundException('ملف السائق غير موجود', 'Driver profile not found');
    return this.prisma.vehicles.create({
      data: {
        driver_id: params.driver_id,
        vehicle_type_id: params.vehicle_type_id,
        plate_number: params.plate_number,
        make: params.make ?? null,
        model: params.model ?? null,
        year: params.year ?? null,
        color: params.color ?? null,
      },
    });
  }

  async listForDriver(driver_id: string) {
    return this.prisma.vehicles.findMany({ where: { driver_id }, orderBy: { created_at: 'desc' } });
  }
}
