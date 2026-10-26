import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class ServiceAreasService {
  constructor(private prisma: PrismaService) {}

  async list() {
    return this.prisma.service_areas.findMany({ where: { is_active: true }, orderBy: { code: 'asc' } });
  }

  async get(id: string) {
    const area = await this.prisma.service_areas.findUnique({ where: { id } });
    if (!area) throw new NotFoundException('المنطقة غير موجودة', 'Service area not found');
    return area;
  }

  async create(data: any) {
    return (this.prisma.service_areas as any).create({ data });
  }

  async update(id: string, data: any) {
    return this.prisma.service_areas.update({ where: { id }, data });
  }

  async coverageCheck(lat: number, lon: number) {
    // PostGIS ST_Covers via $queryRaw; boundary is Unsupported("geography").
    const [row] = (await this.prisma.$queryRaw`
      SELECT id, code FROM service_areas
      WHERE ST_Covers(boundary, ST_SetSRID(ST_MakePoint(${lon}, ${lat})::geometry, 4326)::geography)
      AND is_active = true
      LIMIT 1` as any[]);
    return row ?? null;
  }
}
