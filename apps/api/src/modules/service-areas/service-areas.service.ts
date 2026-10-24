import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class ServiceAreasService {
  constructor(private prisma: PrismaService) {}

  async list() {
    return this.prisma.serviceAreas.findMany({ where: { isActive: true }, orderBy: { code: 'asc' } });
  }

  async get(id: string) {
    const area = await this.prisma.serviceAreas.findUnique({ where: { id } });
    if (!area) throw new NotFoundException('المنطقة غير موجودة', 'Service area not found');
    return area;
  }

  async create(data: any) {
    return this.prisma.serviceAreas.create({ data });
  }

  async update(id: string, data: any) {
    return this.prisma.serviceAreas.update({ where: { id }, data });
  }

  async coverageCheck(lat: number, lon: number) {
    // PostGIS ST_Covers via $queryRaw; boundary is Unsupported("geography").
    const [row] = await this.prisma.$queryRaw`
      SELECT id, code FROM service_areas
      WHERE ST_Covers(boundary, ST_SetSRID(ST_MakePoint(${lon}, ${lat})::geometry, 4326)::geography)
      AND is_active = true
      LIMIT 1`;
    return row ?? null;
  }
}
