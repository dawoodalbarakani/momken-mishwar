import { Injectable, Logger, UnauthorizedException, NotFoundException } from '@nestjs/common';
import * as crypto from 'node:crypto';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service.js';
import * as bcrypt from 'bcryptjs';
import { ConsoleOtpProvider, generateOtpCode, hashCode } from './otp.provider.js';
import { UsersService } from '../users/users.service.js';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private otp: ConsoleOtpProvider,
    private users: UsersService,
  ) {}

  async otpRequest(phone: string, purpose: 'LOGIN' | 'VERIFY_PHONE') {
    const maxAttempts = 5;
    const expiresAt = new Date(Date.now() + 10 * 60_000);
    const code = generateOtpCode();

    await this.prisma.otpChallenges.create({
      data: {
        phoneE164: phone,
        purpose,
        codeHash: hashCode(code),
        maxAttempts,
        expiresAt,
      },
    });

    await this.otp.send(phone, code, purpose);
    return { ok: true, expiresAt };
  }

  async otpVerify(phone: string, code: string, purpose: 'LOGIN' | 'VERIFY_PHONE') {
    const challenge = await this.prisma.otpChallenges.findFirst({
      where: { phoneE164: phone, purpose, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!challenge) throw new UnauthorizedException('رمز التحقق غير صحيح أو منتهي', 'Invalid or expired OTP');
    if (challenge.attempts >= challenge.maxAttempts) {
      throw new UnauthorizedException('تم تجاوز عدد محاولات الرمز', 'Too many OTP attempts');
    }
    if (new Date() >= challenge.expiresAt) {
      throw new UnauthorizedException('رمز التحقق منتهي الصلاحية', 'OTP expired');
    }

    // Compare-and-set the attempt counter so concurrent requests cannot reuse
    // the same stale counter value to exceed maxAttempts.
    const attempt = await this.prisma.otpChallenges.updateMany({
      where: {
        id: challenge.id,
        consumedAt: null,
        attempts: challenge.attempts,
        expiresAt: { gt: new Date() },
      },
      data: { attempts: { increment: 1 } },
    });
    if (attempt.count !== 1) {
      throw new UnauthorizedException('تم استخدام الرمز أو انتهت صلاحيته', 'OTP challenge changed; request a new code');
    }

    const expected = hashCode(code);
    let ok = false;
    // constant-time compare
    const a = Buffer.from(expected, 'utf8');
    const b = Buffer.from(challenge.codeHash, 'utf8');
    if (a.length === b.length) {
      ok = crypto.timingSafeEqual(a, b);
    }
    if (!ok) throw new UnauthorizedException('رمز التحقق غير صحيح', 'Invalid OTP code');

    const consumed = await this.prisma.otpChallenges.updateMany({
      where: { id: challenge.id, consumedAt: null },
      data: { consumedAt: new Date() },
    });
    if (consumed.count !== 1) {
      throw new UnauthorizedException('تم استخدام الرمز بالفعل', 'OTP challenge already consumed');
    }

    let user = await this.prisma.users.findFirst({ where: { phoneE164: phone } });
    if (!user) {
      user = await this.prisma.users.create({
        data: { phoneE164: phone, locale: 'ar' },
      });
      await this.prisma.userRoles.create({ data: { userId: user.id, role: 'CUSTOMER' } });
    }
    return this.issueTokens(user);
  }

  async issueTokens(user: { id: string; phoneE164?: string; email?: string }): Promise<TokenPair> {
    const roles = await this.prisma.userRoles.findMany({ where: { userId: user.id } });
    const roleList = roles.map((r) => r.role);
    const familyId = cryptoRandomUuid();
    const accessToken = this.jwt.sign(
      { sub: user.id, phone: user.phoneE164, email: user.email, roles: roleList },
      { expiresIn: '15m' },
    );
    const refreshToken = await this.saveRefreshToken(user.id, familyId);
    return { accessToken, refreshToken };
  }

  private async saveRefreshToken(userId: string, familyId: string) {
    const token = cryptoRandomUuid();
    const tokenHash = hashCode(token);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60_000);
    await this.prisma.refreshTokens.create({
      data: { userId, familyId, tokenHash, deviceId: null, expiresAt },
    });
    return token;
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const tokenHash = hashCode(refreshToken);
    const token = await this.prisma.refreshTokens.findUnique({ where: { tokenHash } });
    if (!token) throw new UnauthorizedException('توكن التجديد غير صالح', 'Invalid refresh token');
    if (token.revokedAt || token.rotatedAt) {
      // Reuse detected: revoke the whole family.
      await this.prisma.refreshTokens.updateMany({
        where: { familyId: token.familyId },
        data: { revokedAt: new Date(), revokedReason: 'REUSE_DETECTED' },
      });
      throw new UnauthorizedException('تم اكتشاف إعادة استخدام التوكن', 'Refresh token reuse detected');
    }
    if (new Date() >= token.expiresAt) {
      throw new UnauthorizedException('توكن التجديد منتهي الصلاحية', 'Refresh token expired');
    }

    // Rotate: revoke current, issue new family.
    const rotatedAt = new Date();
    const rotation = await this.prisma.refreshTokens.updateMany({
      where: {
        id: token.id,
        revokedAt: null,
        rotatedAt: null,
        expiresAt: { gt: rotatedAt },
      },
      data: { rotatedAt, revokedAt: rotatedAt, revokedReason: 'ROTATED' },
    });
    if (rotation.count !== 1) {
      throw new UnauthorizedException('توكن التجديد استُخدم بالفعل', 'Refresh token has already been used');
    }
    const user = await this.prisma.users.findUnique({ where: { id: token.userId } });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('المستخدم غير نشط', 'User not active');
    }
    return this.issueTokens(user);
  }

  async logout(userId: string) {
    await this.prisma.refreshTokens.updateMany({
      where: { userId },
      data: { revokedAt: new Date(), revokedReason: 'LOGOUT' },
    });
    return { ok: true };
  }

  async loginStaff(email: string, password: string) {
    const user = await this.users.findByEmail(email);
    if (!user || !user.passwordHash) throw new UnauthorizedException('بيانات دخول غير صحيحة', 'Invalid credentials');
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('بيانات دخول غير صحيحة', 'Invalid credentials');
    return this.issueTokens(user);
  }
}

function cryptoRandomUuid(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (crypto.randomBytes(1)[0] % 16) & 0xf;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}
