import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class AuditLogsService {
  constructor(private prisma: PrismaService) {}

  async log(params: {
    actorUserId?: string;
    actorRole?: string;
    action: string;
    entityType: string;
    entityId?: string;
    beforeState?: any;
    afterState?: any;
    reason?: string;
    ip?: string;
    userAgent?: string;
    requestId?: string;
  }) {
    return this.prisma.auditLogs.create({ data: params });
  }

  async list(query: { entityType?: string; entityId?: string; limit?: number; cursor?: string }) {
    const limit = Math.min(query.limit ?? 50, 100);
    return this.prisma.auditLogs.findMany({
      where: {
        ...(query.entityType ? { entityType: query.entityType } : {}),
        ...(query.entityId ? { entityId: query.entityId } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      ...(query.cursor ? { cursor: { id: Number(query.cursor) }, skip: 1 } : {}),
    });
  }
}
