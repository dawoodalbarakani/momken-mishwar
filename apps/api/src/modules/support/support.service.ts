import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

@Injectable()
export class SupportService {
  constructor(private prisma: PrismaService) {}

  async createTicket(params: { reporterId: string; rideId?: string; category: string; subject: string; description: string }) {
    return this.prisma.supportTickets.create({ data: params });
  }

  async addNote(params: { ticketId: string; authorId: string; body: string; isInternal?: boolean }) {
    return this.prisma.supportTicketNotes.create({ data: params });
  }

  async list(query: { status?: string; limit?: number }) {
    return this.prisma.supportTickets.findMany({
      where: query.status ? { status: query.status } : {},
      orderBy: { createdAt: 'desc' },
      take: Math.min(query.limit ?? 50, 100),
    });
  }
}
