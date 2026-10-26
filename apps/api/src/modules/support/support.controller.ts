import {
  Controller,
  Post,
  Get,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { SupportService } from './support.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Support')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('support/tickets')
export class SupportController {
  constructor(private readonly service: SupportService) {}

  @Post()
  @ApiOperation({ summary: 'Create a support ticket' })
  create(@Body() body: any, @CurrentUser() user: any) {
    return this.service.createTicket({ ...body, reporter_id: user.sub });
  }

  @Post(':ticket_id/notes')
  @ApiOperation({ summary: 'Add a note to a ticket' })
  @Roles('SUPPORT_AGENT', 'OPERATIONS_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  addNote(@Body() body: any, @CurrentUser() user: any) {
    return this.service.addNote({ ...body, author_id: user.sub });
  }

  @Get()
  @ApiOperation({ summary: 'List support tickets' })
  @Roles('SUPPORT_AGENT', 'OPERATIONS_MANAGER', 'ADMIN', 'SUPER_ADMIN')
  list(@Query() query: any) {
    return this.service.list(query);
  }
}
