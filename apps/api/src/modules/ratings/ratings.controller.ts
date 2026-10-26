import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { RatingsService } from './ratings.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Ratings')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('ratings')
export class RatingsController {
  constructor(private readonly service: RatingsService) {}

  @Post()
  @ApiOperation({ summary: 'Rate a ride participant' })
  @Roles('CUSTOMER', 'DRIVER')
  create(@Body() body: any, @CurrentUser() user: any) {
    return this.service.create({ ...body, rater_id: user.sub });
  }

  @Get('me')
  @ApiOperation({ summary: 'Ratings received by me' })
  mine(@Query('ratee_id') ratee_id: string) {
    return this.service.listForRatee(ratee_id);
  }
}
