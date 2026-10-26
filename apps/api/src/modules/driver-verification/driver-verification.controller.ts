import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DriverVerificationService, VerificationStatus } from './driver-verification.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('DriverVerification')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('driver-verification')
export class DriverVerificationController {
  constructor(private readonly service: DriverVerificationService) {}

  @Post('review')
  @ApiOperation({ summary: 'Approve/reject/suspend a driver (four-eyes via reviewer)' })
  @Roles('OPERATIONS_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  review(@Body() body: { driver_id: string; status: VerificationStatus; note?: string; rejection_reason?: string }, @CurrentUser() user: any) {
    return this.service.review({ ...body, reviewedBy: user.sub });
  }

  @Get(':driver_id/status')
  @ApiOperation({ summary: 'Get driver verification status' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER', 'SUPPORT_AGENT', 'DRIVER')
  status(@Param('driver_id') driver_id: string) {
    return this.service.getStatus(driver_id);
  }
}
