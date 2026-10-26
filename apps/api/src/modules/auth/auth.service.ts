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
    const max_attempts = 5;
    const expires_at = new Date(Date.now() + 10 * 60_000);
    const code = generateOtpCode();

    await this.prisma.otp_challenges.create({
      data: {
        phone_e164: phone,
        purpose,
        code_hash: hashCode(code),
        max_attempts,
        expires_at,
      },
    });

    await this.otp.send(phone, code, purpose);
    return { ok: true, expires_at };
  }

  async otpVerify(phone: string, code: string, purpose: 'LOGIN' | 'VERIFY_PHONE') {
    const challenge = await this.prisma.otp_challenges.findFirst({
      where: { phone_e164: phone, purpose, consumed_at: null },
      orderBy: { created_at: 'desc' },
    });
    if (!challenge) throw new UnauthorizedException('رمز التحقق غير صحيح أو منتهي', 'Invalid or expired OTP');
    if (challenge.attempts >= challenge.max_attempts) {
      throw new UnauthorizedException('تم تجاوز عدد محاولات الرمز', 'Too many OTP attempts');
    }
    if (new Date() >= challenge.expires_at) {
      throw new UnauthorizedException('رمز التحقق منتهي الصلاحية', 'OTP expired');
    }

    // Compare-and-set the attempt counter so concurrent requests cannot reuse
    // the same stale counter value to exceed max_attempts.
    const attempt = await this.prisma.otp_challenges.updateMany({
      where: {
        id: challenge.id,
        consumed_at: null,
        attempts: challenge.attempts,
        expires_at: { gt: new Date() },
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
    const b = Buffer.from(challenge.code_hash, 'utf8');
    if (a.length === b.length) {
      ok = crypto.timingSafeEqual(a, b);
    }
    if (!ok) throw new UnauthorizedException('رمز التحقق غير صحيح', 'Invalid OTP code');

    const consumed = await this.prisma.otp_challenges.updateMany({
      where: { id: challenge.id, consumed_at: null },
      data: { consumed_at: new Date() },
    });
    if (consumed.count !== 1) {
      throw new UnauthorizedException('تم استخدام الرمز بالفعل', 'OTP challenge already consumed');
    }

    let user = await this.prisma.users.findFirst({ where: { phone_e164: phone } });
    if (!user) {
      user = await this.prisma.users.create({
        data: { phone_e164: phone, locale: 'ar' },
      });
      await this.prisma.user_roles.create({ data: { user_id: user.id, role: 'CUSTOMER' } });
    }
    return this.issueTokens(user);
  }

  async issueTokens(user: { id: string; phone_e164?: string | null; email?: string | null }): Promise<TokenPair> {
    const roles = await this.prisma.user_roles.findMany({ where: { user_id: user.id } });
    const roleList = roles.map((r) => r.role);
    const family_id = cryptoRandomUuid();
    const accessToken = this.jwt.sign(
      { sub: user.id, phone: user.phone_e164, email: user.email, roles: roleList },
      { expiresIn: '15m' },
    );
    const refreshToken = await this.saveRefreshToken(user.id, family_id);
    return { accessToken, refreshToken };
  }

  private async saveRefreshToken(user_id: string, family_id: string) {
    const token = cryptoRandomUuid();
    const token_hash = hashCode(token);
    const expires_at = new Date(Date.now() + 7 * 24 * 60 * 60_000);
    await this.prisma.refresh_tokens.create({
      data: { user_id, family_id, token_hash, device_id: null, expires_at },
    });
    return token;
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const token_hash = hashCode(refreshToken);
    const token = await this.prisma.refresh_tokens.findUnique({ where: { token_hash } });
    if (!token) throw new UnauthorizedException('توكن التجديد غير صالح', 'Invalid refresh token');
    if (token.revoked_at || token.rotated_at) {
      // Reuse detected: revoke the whole family.
      await this.prisma.refresh_tokens.updateMany({
        where: { family_id: token.family_id },
        data: { revoked_at: new Date(), revoked_reason: 'REUSE_DETECTED' },
      });
      throw new UnauthorizedException('تم اكتشاف إعادة استخدام التوكن', 'Refresh token reuse detected');
    }
    if (new Date() >= token.expires_at) {
      throw new UnauthorizedException('توكن التجديد منتهي الصلاحية', 'Refresh token expired');
    }

    // Rotate: revoke current, issue new family.
    const rotated_at = new Date();
    const rotation = await this.prisma.refresh_tokens.updateMany({
      where: {
        id: token.id,
        revoked_at: null,
        rotated_at: null,
        expires_at: { gt: rotated_at },
      },
      data: { rotated_at, revoked_at: rotated_at, revoked_reason: 'ROTATED' },
    });
    if (rotation.count !== 1) {
      throw new UnauthorizedException('توكن التجديد استُخدم بالفعل', 'Refresh token has already been used');
    }
    const user = await this.prisma.users.findUnique({ where: { id: token.user_id } });
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('المستخدم غير نشط', 'User not active');
    }
    return this.issueTokens(user);
  }

  async logout(user_id: string) {
    await this.prisma.refresh_tokens.updateMany({
      where: { user_id },
      data: { revoked_at: new Date(), revoked_reason: 'LOGOUT' },
    });
    return { ok: true };
  }

  async loginStaff(email: string, password: string) {
    const user = await this.users.findByEmail(email);
    if (!user || !user.password_hash) throw new UnauthorizedException('بيانات دخول غير صحيحة', 'Invalid credentials');
    const ok = await bcrypt.compare(password, user.password_hash);
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
