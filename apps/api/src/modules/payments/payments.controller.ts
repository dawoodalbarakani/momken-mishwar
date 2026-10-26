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

  @Post('rides/:ride_id')
  @ApiOperation({ summary: 'Record a cash payment for a ride' })
  @Roles('CUSTOMER', 'DRIVER')
  create(@Param('ride_id') ride_id: string, @Body() body: any) {
    return this.service.createForRide({ ride_id, ...body });
  }

  @Get()
  @ApiOperation({ summary: 'List payment records' })
  @Roles('FINANCE_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  list(@Query() query: any) {
    return this.service.list(query);
  }
}
