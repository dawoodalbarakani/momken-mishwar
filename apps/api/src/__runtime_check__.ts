import { PrismaClient } from './generated/prisma/client.js';
import { PrismaPg } from '@prisma/adapter-pg';

const adapter = new PrismaPg({
  connectionString: 'postgres://mishwar:mishwar_test_only@localhost:5433/mishwar_test',
});

const prisma = new PrismaClient({ adapter });

async function main() {
  await prisma.$connect();
  try {
    const areas = await prisma.service_areas.findMany();
    const sanaa = areas.find((a: any) => a.code === 'SANAA');
    if (!sanaa) throw new Error('SANAA service area not found in service_areas');
    console.log('service_areas:', JSON.stringify(areas.map((a: any) => ({ id: a.id, code: a.code }))));

    const vtypes = await prisma.vehicle_types.findMany();
    console.log('vehicle_types:', JSON.stringify(vtypes.map((v: any) => ({ id: v.id, code: v.code }))));

    console.log('نجح');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error('فشل:', e instanceof Error ? e.message : String(e));
  process.exit(1);
});
