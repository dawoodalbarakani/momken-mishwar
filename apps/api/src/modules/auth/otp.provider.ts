import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import * as crypto from 'node:crypto';

export interface OtpProvider {
  send(phone: string, code: string, purpose: string): Promise<void>;
}

@Injectable()
export class ConsoleOtpProvider implements OtpProvider, OnModuleInit {
  private readonly logger = new Logger(ConsoleOtpProvider.name);
  constructor(private prisma: PrismaService) {}

  onModuleInit() {
    if (process.env.NODE_ENV === 'production' && process.env.OTP_PROVIDER === 'console') {
      throw new Error(
        '[auth] OTP_PROVIDER=console is not allowed in production. Configure an SMS provider.',
      );
    }
  }

  async send(phone: string, code: string, purpose: string) {
    this.logger.warn(`[OTP][${purpose}] code for ${phone}: ${code}`);
    if (process.env.OTP_DEV_DISPLAY === 'true') {
      this.logger.log(`[OTP DEV] ${phone} => ${code}`);
    }
  }
}

export function generateOtpCode(): string {
  return crypto.randomInt(100_000, 999_999).toString();
}

export function hashCode(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}
