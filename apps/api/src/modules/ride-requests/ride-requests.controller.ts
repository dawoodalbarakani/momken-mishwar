import {
  Controller,
  Post,
  Get,
  Param,
  Body,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { RideRequestsService } from './ride-requests.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';
import { Idempotency } from '../../common/decorators/idempotency.decorator.js';

@ApiTags('RideRequests')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('rides')
export class RideRequestsController {
  constructor(private readonly service: RideRequestsService) {}

  @Post()
  @ApiOperation({ summary: 'Request a ride (server-computed price, idempotent)' })
  @Roles('CUSTOMER')
  @Idempotency()
  create(@Body() body: any, @CurrentUser() user: any) {
    return this.service.create({
      customerId: user.sub,
      serviceAreaId: body.serviceAreaId,
      vehicleTypeId: body.vehicleTypeId,
      pickupLat: body.pickupLat,
      pickupLon: body.pickupLon,
      destLat: body.destLat,
      destLon: body.destLon,
      idempotencyKey: body.idempotencyKey,
    });
  }

  @Get('active')
  @ApiOperation({ summary: "Customer's active ride" })
  @Roles('CUSTOMER')
  active(@CurrentUser() user: any) {
    return this.service.active(user.sub);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a ride by id' })
  @Roles('CUSTOMER', 'DRIVER', 'SUPPORT_AGENT', 'OPERATIONS_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.findOne(id);
  }

  @Post(':id/cancel')
  @ApiOperation({ summary: 'Cancel a ride (idempotent)' })
  @Roles('CUSTOMER')
  @Idempotency()
  cancel(@Param('id') id: string, @Body() body: { reasonCode: string; note?: string }, @CurrentUser() user: any) {
    return this.service.cancel({ rideId: id, customerId: user.sub, reasonCode: body.reasonCode, note: body.note });
  }
}
