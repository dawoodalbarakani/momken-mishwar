import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class VehiclesService {
  constructor(private prisma: PrismaService) {}

  async create(params: { driverId: string; vehicleTypeId: string; plateNumber: string; make?: string; model?: string; year?: number; color?: string }) {
    const driver = await this.prisma.driverProfiles.findUnique({ where: { userId: params.driverId } });
    if (!driver) throw new NotFoundException('ملف السائق غير موجود', 'Driver profile not found');
    return this.prisma.vehicles.create({
      data: {
        driverId: params.driverId,
        vehicleTypeId: params.vehicleTypeId,
        plateNumber: params.plateNumber,
        make: params.make ?? null,
        model: params.model ?? null,
        year: params.year ?? null,
        color: params.color ?? null,
      },
    });
  }

  async listForDriver(driverId: string) {
    return this.prisma.vehicles.findMany({ where: { driverId }, orderBy: { createdAt: 'desc' } });
  }
}
