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
    let password_hash: string | undefined;
    if (data.password) {
      password_hash = await bcrypt.hash(data.password, 10);
    }
    return this.prisma.users.create({
      data: {
        phone_e164: data.phone_e164 ?? null,
        email: data.email ?? null,
        display_name: data.display_name ?? null,
        locale: data.locale ?? 'ar',
        password_hash,
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

  async updatePassword(user_id: string, password: string) {
    const password_hash = await bcrypt.hash(password, 10);
    return this.prisma.users.update({ where: { id: user_id }, data: { password_hash } });
  }

  async grantRole(user_id: string, role: string, granted_by: string) {
    return this.prisma.user_roles.upsert({
      where: { user_id_role: { user_id, role } },
      update: {},
      create: { user_id, role, granted_by },
    });
  }
}
