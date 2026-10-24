import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Notifications')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a notification (Arabic templates supported)' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER', 'SUPPORT_AGENT')
  create(@Body() body: any, @CurrentUser() user: any) {
    return this.service.create({ ...body, userId: body.userId });
  }

  @Get('me')
  @ApiOperation({ summary: 'My notifications' })
  mine(@CurrentUser() user: any) {
    return this.service.listForUser(user.sub);
  }

  @Post(':id/read')
  @ApiOperation({ summary: 'Mark notification as read' })
  read(@Param('id') id: string, @CurrentUser() user: any) {
    return this.service.markRead(id, user.sub);
  }
}
