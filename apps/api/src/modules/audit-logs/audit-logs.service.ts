import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class AuditLogsService {
  constructor(private prisma: PrismaService) {}

  async log(params: {
    actor_user_id?: string;
    actor_role?: string;
    action: string;
    entity_type: string;
    entity_id?: string;
    before_state?: any;
    after_state?: any;
    reason?: string;
    ip?: string;
    user_agent?: string;
    request_id?: string;
  }) {
    return this.prisma.audit_logs.create({ data: params });
  }

  async list(query: { entity_type?: string; entity_id?: string; limit?: number; cursor?: string }) {
    const limit = Math.min(query.limit ?? 50, 100);
    return this.prisma.audit_logs.findMany({
      where: {
        ...(query.entity_type ? { entity_type: query.entity_type } : {}),
        ...(query.entity_id ? { entity_id: query.entity_id } : {}),
      },
      orderBy: { created_at: 'desc' },
      take: limit,
      ...(query.cursor ? { cursor: { id: Number(query.cursor) }, skip: 1 } : {}),
    });
  }
}
