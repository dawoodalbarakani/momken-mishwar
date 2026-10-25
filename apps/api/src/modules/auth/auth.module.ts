import { Module, OnModuleInit, Logger } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service.js';
import { AuthController } from './auth.controller.js';
import { ConsoleOtpProvider } from './otp.provider.js';
import { UsersModule } from '../users/users.module.js';

@Module({
  imports: [
    UsersModule,
    JwtModule.register({
      global: true,
      secret: process.env.JWT_ACCESS_SECRET,
      signOptions: { expiresIn: '15m' },
    }),
  ],
  providers: [AuthService, ConsoleOtpProvider],
  controllers: [AuthController],
  exports: [AuthService],
})
export class AuthModule implements OnModuleInit {
  private readonly logger = new Logger(AuthModule.name);

  onModuleInit() {
    if (process.env.NODE_ENV === 'production' && process.env.OTP_PROVIDER === 'console') {
      throw new Error(
        '[auth] OTP_PROVIDER=console is not allowed in production. Configure an SMS provider.',
      );
    }
  }
}
