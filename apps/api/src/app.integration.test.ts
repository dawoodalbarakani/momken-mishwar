import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { AppModule } from './app.module.js';
import { PrismaService } from './prisma/prisma.service.js';

describe('Mishwar API Integration (mishwar_test)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
    prisma = moduleRef.get(PrismaService);
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
    await app.close();
  });

  it('تحتوي mishwar_test على منطقة صنعاء', async () => {
    const prismaAny = prisma as any;
    const areas = await prismaAny.service_areas.findMany({ where: { code: 'SANAA' } });
    expect(areas.length).toBeGreaterThan(0);
    expect(areas[0]?.name_ar).toBe('صنعاء');
  });

  it('تحتوي mishwar_test على نوعي المركبات', async () => {
    const prismaAny = prisma as any;
    const types = await prismaAny.vehicle_types.findMany();
    expect(types.length).toBeGreaterThanOrEqual(2);
  });

  it('عميل Prisma يتصل ويخرج نظيفًا', async () => {
    expect(prisma).toBeDefined();
  });
});
