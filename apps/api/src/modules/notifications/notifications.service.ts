import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class NotificationsService {
  constructor(private prisma: PrismaService) {}

  async create(params: {
    user_id: string;
    kind: string;
    title: string;
    body: string;
    data?: any;
    dedupe_key?: string;
    locale?: 'ar' | 'en';
  }) {
    return this.prisma.notifications.create({
      data: {
        user_id: params.user_id,
        kind: params.kind,
        title: params.title,
        body: params.body,
        data: params.data ?? {},
        dedupe_key: params.dedupe_key ?? null,
      },
    });
  }

  async listForUser(user_id: string, limit = 50) {
    return this.prisma.notifications.findMany({
      where: { user_id },
      orderBy: { created_at: 'desc' },
      take: Math.min(limit, 100),
    });
  }

  async markRead(id: string, user_id: string) {
    return this.prisma.notifications.update({
      where: { id },
      data: { read_at: new Date() },
    });
  }
}
