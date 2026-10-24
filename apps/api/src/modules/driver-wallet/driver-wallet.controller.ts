import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DriverWalletService } from './driver-wallet.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('DriverWallet')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('driver')
export class DriverWalletController {
  constructor(private readonly service: DriverWalletService) {}

  @Get('earnings')
  @ApiOperation({ summary: 'Driver wallet balance' })
  @Roles('DRIVER')
  earnings(@CurrentUser() user: any, @Query('currency') currency = 'YER') {
    return this.service.balance(user.sub, currency);
  }

  @Get('ledger')
  @ApiOperation({ summary: 'Driver ledger entries (append-only)' })
  @Roles('DRIVER')
  ledger(@CurrentUser() user: any, @Query('limit') limit = 50) {
    return this.service.ledger(user.sub, Number(limit));
  }

  @Post('payout-requests')
  @ApiOperation({ summary: 'Request a payout (four-eyes: approved by finance/admin)' })
  @Roles('DRIVER')
  requestPayout(@Body() body: any, @CurrentUser() user: any) {
    return this.service.requestPayout({ ...body, driverId: user.sub, requestedBy: user.sub });
  }
}
