import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuditLogsService } from './audit-logs.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('AuditLogs')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('audit-logs')
export class AuditLogsController {
  constructor(private readonly service: AuditLogsService) {}

  @Post()
  @ApiOperation({ summary: 'Create an audit log entry (append-only)' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_MANAGER')
  create(@Body() body: any, @CurrentUser() user: any) {
    return this.service.log({
      ...body,
      actorUserId: user?.sub,
      actorRole: user?.roles?.[0],
      requestId: body.requestId,
    });
  }

  @Get()
  @ApiOperation({ summary: 'List audit log entries' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER', 'FINANCE_MANAGER', 'SUPPORT_AGENT')
  list(@Query() query: any) {
    return this.service.list(query);
  }
}
