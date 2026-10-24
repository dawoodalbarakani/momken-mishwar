import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class NotificationsService {
  constructor(private prisma: PrismaService) {}

  async create(params: {
    userId: string;
    kind: string;
    title: string;
    body: string;
    data?: any;
    dedupeKey?: string;
    locale?: 'ar' | 'en';
  }) {
    return this.prisma.notifications.create({
      data: {
        userId: params.userId,
        kind: params.kind,
        title: params.title,
        body: params.body,
        data: params.data ?? {},
        dedupeKey: params.dedupeKey ?? null,
      },
    });
  }

  async listForUser(userId: string, limit = 50) {
    return this.prisma.notifications.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 100),
    });
  }

  async markRead(id: string, userId: string) {
    return this.prisma.notifications.update({
      where: { id },
      data: { readAt: new Date() },
    });
  }
}
