import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '../generated/prisma/client.js';
import { PrismaPg } from '@prisma/adapter-pg';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  /**
   * Run Prisma statements inside a transaction. Use this for any multi-row write
   * that needs FOR UPDATE locking (e.g. ride assignment, offer acceptance).
   */
  async tx<T>(fn: (tx: PrismaClient) => Promise<T>): Promise<T> {
    return (this.$transaction(fn as any) as unknown) as T;
  }
}
