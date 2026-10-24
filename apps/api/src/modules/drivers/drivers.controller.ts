import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
  Param,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DriversService } from './drivers.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Drivers')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('drivers')
export class DriversController {
  constructor(private readonly service: DriversService) {}

  @Get('me/profile')
  @ApiOperation({ summary: 'My driver profile' })
  @Roles('DRIVER')
  profile(@CurrentUser() user: any) {
    return this.service.getProfile(user.sub);
  }

  @Post('me/availability')
  @ApiOperation({ summary: 'Set online/offline availability' })
  @Roles('DRIVER')
  availability(@Body() body: { isOnline: boolean }, @CurrentUser() user: any) {
    return this.service.setOnline(user.sub, body.isOnline);
  }

  @Get()
  @ApiOperation({ summary: 'List drivers (admin)' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER', 'SUPPORT_AGENT')
  list(@Query() query: any) {
    return this.service.list(query);
  }
}
