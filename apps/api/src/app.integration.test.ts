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
    if (prisma) await prisma.$disconnect();
    if (app) await app.close();
  });

  it('queries the service areas table', async () => {
    const areas = await (prisma as any).service_areas.findMany({ take: 1 });
    expect(Array.isArray(areas)).toBe(true);
  });

  it('queries the vehicle types table', async () => {
    const types = await (prisma as any).vehicle_types.findMany({ take: 1 });
    expect(Array.isArray(types)).toBe(true);
  });

  it('initializes a connected Prisma client', async () => {
    expect(prisma).toBeDefined();
  });
});
