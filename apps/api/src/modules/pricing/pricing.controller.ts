import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PricingService } from './pricing.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';

@ApiTags('Pricing')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('quotes')
export class PricingController {
  constructor(private readonly service: PricingService) {}

  @Post()
  @ApiOperation({ summary: 'Server-computed price quote (client must not send a price)' })
  quote(@Body() body: any) {
    return this.service.quote({
      pickupLat: body.pickupLat,
      pickupLon: body.pickupLon,
      destLat: body.destLat,
      destLon: body.destLon,
      serviceAreaId: body.serviceAreaId,
      vehicleTypeId: body.vehicleTypeId,
    });
  }

  @Get('pricing-rules')
  @ApiOperation({ summary: 'List active pricing rules' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER')
  rules(@Query('serviceAreaId') serviceAreaId?: string) {
    return this.service.listRules(serviceAreaId);
  }
}
