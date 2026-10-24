import {
  Controller,
  Post,
  Param,
  Body,
  Get,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { TripsService } from './trips.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Trips')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('rides')
export class TripsController {
  constructor(private readonly service: TripsService) {}

  @Post(':id/en-route')
  @ApiOperation({ summary: 'Driver en route (ASSIGNED -> ARRIVING)' })
  @Roles('DRIVER')
  enRoute(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: any) {
    return this.service.enRoute(id, user.sub);
  }

  @Post(':id/arrived')
  @ApiOperation({ summary: 'Driver arrived (ARRIVING -> ARRIVED)' })
  @Roles('DRIVER')
  arrived(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: any) {
    return this.service.arrived(id, user.sub);
  }

  @Post(':id/start')
  @ApiOperation({ summary: 'Start trip (ARRIVED -> IN_PROGRESS), requires start code' })
  @Roles('DRIVER')
  start(@Param('id', ParseUUIDPipe) id: string, @Body() body: { code: string }, @CurrentUser() user: any) {
    return this.service.startTrip({ rideId: id, driverId: user.sub, code: body.code });
  }

  @Post(':id/complete')
  @ApiOperation({ summary: 'Complete trip (IN_PROGRESS -> COMPLETED)' })
  @Roles('DRIVER')
  complete(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: any) {
    return this.service.complete({ rideId: id, driverId: user.sub });
  }

  @Get(':id/start-code')
  @ApiOperation({ summary: 'Get derived start code (customer owner only)' })
  @Roles('CUSTOMER')
  startCode(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: any) {
    return this.service.startCode(id, user.sub);
  }
}
