import {
  Controller,
  Post,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { DispatchService } from './dispatch.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Dispatch')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('dispatch')
export class DispatchController {
  constructor(private readonly service: DispatchService) {}

  @Post('rides/:ride_id/search')
  @ApiOperation({ summary: 'Start driver search and create offers' })
  @Roles('SYSTEM')
  search(@Param('ride_id') ride_id: string) {
    return this.service.search(ride_id);
  }

  @Post('offers/:offerId/accept')
  @ApiOperation({ summary: 'Accept a ride offer (atomic assignment)' })
  @Roles('DRIVER')
  accept(@Param('offerId') offerId: string, @Body() body: { vehicle_id: string }, @CurrentUser() user: any) {
    return this.service.acceptOffer({ offerId, driver_id: user.sub, vehicle_id: body.vehicle_id });
  }

  @Post('sweep')
  @ApiOperation({ summary: 'Expire offers and timed-out searches (cron/job)' })
  @Roles('SYSTEM', 'ADMIN', 'SUPER_ADMIN')
  sweep() {
    return this.service.sweep();
  }
}
