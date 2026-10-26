import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class SupportService {
  constructor(private prisma: PrismaService) {}

  async createTicket(params: { reporter_id: string; ride_id?: string; category: string; subject: string; description: string }) {
    return this.prisma.support_tickets.create({ data: params });
  }

  async addNote(params: { ticket_id: string; author_id: string; body: string; is_internal?: boolean }) {
    return this.prisma.support_ticket_notes.create({ data: params });
  }

  async list(query: { status?: string; limit?: number }) {
    return this.prisma.support_tickets.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { created_at: 'desc' },
      take: Math.min(query.limit ?? 50, 100),
    });
  }
}
