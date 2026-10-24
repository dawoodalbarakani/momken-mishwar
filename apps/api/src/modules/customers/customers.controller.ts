import {
  Controller,
  Get,
  Post,
  Body,
  UseGuards,
  Param,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CustomersService } from './customers.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Customers')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('customers')
export class CustomersController {
  constructor(private readonly service: CustomersService) {}

  @Get('me/profile')
  @ApiOperation({ summary: 'Get or create customer profile' })
  @Roles('CUSTOMER')
  profile(@CurrentUser() user: any) {
    return this.service.getOrCreateProfile(user.sub);
  }

  @Get('me/saved-places')
  @ApiOperation({ summary: 'List saved places' })
  @Roles('CUSTOMER')
  savedPlaces(@CurrentUser() user: any) {
    return this.service.listSavedPlaces(user.sub);
  }

  @Post('me/saved-places')
  @ApiOperation({ summary: 'Add a saved place' })
  @Roles('CUSTOMER')
  add(@Body() body: any, @CurrentUser() user: any) {
    return this.service.getOrCreateProfile(user.sub).then((p) =>
      this.service.addSavedPlace({ customerId: p.userId, ...body }),
    );
  }
}
