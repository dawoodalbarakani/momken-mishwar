import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { PaymentsService } from './payments.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';

@ApiTags('Payments')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('payments')
export class PaymentsController {
  constructor(private readonly service: PaymentsService) {}

  @Post('rides/:rideId')
  @ApiOperation({ summary: 'Record a cash payment for a ride' })
  @Roles('CUSTOMER', 'DRIVER')
  create(@Param('rideId') rideId: string, @Body() body: any) {
    return this.service.createForRide({ rideId, ...body });
  }

  @Get()
  @ApiOperation({ summary: 'List payment records' })
  @Roles('FINANCE_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  list(@Query() query: any) {
    return this.service.list(query);
  }
}
