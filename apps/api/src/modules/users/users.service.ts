import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import * as bcrypt from 'bcryptjs';
import { CreateUserDto } from './dtos/create-user.dto.js';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async create(data: CreateUserDto) {
    if (data.email) {
      const exists = await this.prisma.users.findUnique({ where: { email: data.email } });
      if (exists) throw new ConflictException('البريد الإلكتروني مستخدم مسبقاً', 'Email already in use');
    }
    let passwordHash: string | undefined;
    if (data.password) {
      passwordHash = await bcrypt.hash(data.password, 10);
    }
    return this.prisma.users.create({
      data: {
        phoneE164: data.phoneE164 ?? null,
        email: data.email ?? null,
        displayName: data.displayName ?? null,
        locale: data.locale ?? 'ar',
        passwordHash,
      },
    });
  }

  async findById(id: string) {
    const user = await this.prisma.users.findUnique({ where: { id } });
    if (!user) throw new NotFoundException('المستخدم غير موجود', 'User not found');
    return user;
  }

  async findByEmail(email: string) {
    return this.prisma.users.findUnique({ where: { email } });
  }

  async updatePassword(userId: string, password: string) {
    const passwordHash = await bcrypt.hash(password, 10);
    return this.prisma.users.update({ where: { id: userId }, data: { passwordHash } });
  }

  async grantRole(userId: string, role: string, grantedBy: string) {
    return this.prisma.userRoles.upsert({
      where: { userId_role: { userId, role } },
      update: {},
      create: { userId, role, grantedBy },
    });
  }
}
