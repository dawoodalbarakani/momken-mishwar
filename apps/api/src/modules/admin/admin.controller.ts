import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AdminService } from './admin.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Admin')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly service: AdminService) {}

  @Get('drivers')
  @ApiOperation({ summary: 'List drivers' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER')
  drivers(@Query() q: any) {
    return this.service.listDrivers(q);
  }

  @Get('rides')
  @ApiOperation({ summary: 'List rides (admin)' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER', 'SUPPORT_AGENT')
  rides(@Query() q: any) {
    return this.service.listRides(q);
  }

  @Post('rides/:id/cancel')
  @ApiOperation({ summary: 'Staff cancels a ride' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER', 'SUPPORT_AGENT')
  cancelRide(@Param('id') id: string, @Body() body: { reason: string }, @CurrentUser() user: any) {
    return this.service.cancelRide(id, body.reason, user.sub);
  }

  @Get('pricing-rules')
  @ApiOperation({ summary: 'List pricing rules' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER')
  pricingRules(@Query() q: any) {
    return this.service.listPricingRules(q);
  }

  @Get('payouts')
  @ApiOperation({ summary: 'List driver payouts' })
  @Roles('FINANCE_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  payouts(@Query() q: any) {
    return this.service.listPayouts(q);
  }

  @Post('payouts/:id/approve')
  @ApiOperation({ summary: 'Approve a payout (four-eyes)' })
  @Roles('FINANCE_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  approvePayout(@Param('id') id: string, @CurrentUser() user: any) {
    return this.service.approvePayout(id, user.sub);
  }

  @Get('driver-balances')
  @ApiOperation({ summary: 'All driver balances (ledger view)' })
  @Roles('FINANCE_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  balances() {
    return this.service.driverBalances();
  }

  @Get('dashboard/stats')
  @ApiOperation({ summary: 'Admin dashboard statistics' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER')
  stats() {
    return this.service.stats();
  }
}
