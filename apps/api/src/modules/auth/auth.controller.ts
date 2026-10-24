import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService, TokenPair } from './auth.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';

export interface OtpRequestDto {
  phone: string;
  purpose?: 'LOGIN' | 'VERIFY_PHONE';
}
export interface OtpVerifyDto {
  phone: string;
  code: string;
  purpose?: 'LOGIN' | 'VERIFY_PHONE';
}
export interface RefreshDto {
  refreshToken: string;
}

@Controller('auth')
@ApiTags('Auth')
export class AuthController {
  constructor(private readonly service: AuthService) {}

  @Post('otp/request')
  @ApiOperation({ summary: 'Request an OTP code (console provider in dev)' })
  async otpRequest(@Body() body: OtpRequestDto) {
    return this.service.otpRequest(body.phone, body.purpose ?? 'LOGIN');
  }

  @Post('otp/verify')
  @ApiOperation({ summary: 'Verify OTP and issue access + refresh tokens' })
  async otpVerify(@Body() body: OtpVerifyDto): Promise<TokenPair> {
    return this.service.otpVerify(body.phone, body.code, body.purpose ?? 'LOGIN');
  }

  @Post('refresh')
  @ApiOperation({ summary: 'Rotate refresh token and issue a new pair' })
  async refresh(@Body() body: RefreshDto): Promise<TokenPair> {
    return this.service.refresh(body.refreshToken);
  }

  @Post('logout')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Revoke all refresh tokens for the current user' })
  async logout(@Req() req: any) {
    return this.service.logout(req.user.sub);
  }
}
