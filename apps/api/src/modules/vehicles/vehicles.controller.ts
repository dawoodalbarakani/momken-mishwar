import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { VehiclesService } from './vehicles.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Vehicles')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('vehicles')
export class VehiclesController {
  constructor(private readonly service: VehiclesService) {}

  @Post()
  @ApiOperation({ summary: 'Register a vehicle for a driver' })
  @Roles('DRIVER')
  create(@Body() body: any, @CurrentUser() user: any) {
    return this.service.create({ ...body, driverId: user.sub });
  }

  @Get('me')
  @ApiOperation({ summary: 'My vehicles' })
  @Roles('DRIVER')
  mine(@CurrentUser() user: any) {
    return this.service.listForDriver(user.sub);
  }
}
