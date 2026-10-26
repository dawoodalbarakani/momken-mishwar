import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DriverLocationsService } from './driver-locations.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('DriverLocations')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('driver/location')
export class DriverLocationsController {
  constructor(private readonly service: DriverLocationsService) {}

  @Post()
  @ApiOperation({ summary: 'Push driver location batch' })
  @Roles('DRIVER')
  updateBatch(@Body() body: { updates: any[] }, @CurrentUser() user: any) {
    return this.service.updateBatch({ driver_id: user.sub, ...body });
  }

  @Get('latest')
  @ApiOperation({ summary: "Driver's last known location with age" })
  @Roles('DRIVER')
  latest(@CurrentUser() user: any) {
    return this.service.latest(user.sub);
  }
}
