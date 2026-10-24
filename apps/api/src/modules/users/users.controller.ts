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
import { UsersService } from './users.service.js';
import { CreateUserDto } from './dtos/create-user.dto.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { CurrentUser } from '../../common/decorators/current-user.decorator.js';

@ApiTags('Users')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly service: UsersService) {}

  @Post()
  @ApiOperation({ summary: 'Create a user (admin/staff)' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER')
  create(@Body() dto: CreateUserDto, @CurrentUser() user: any) {
    return this.service.create(dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user by id' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'SUPPORT_AGENT')
  findById(@Param('id', ParseUUIDPipe) id: string) {
    return this.service.findById(id);
  }

  @Post(':id/roles')
  @ApiOperation({ summary: 'Grant a role to a user' })
  @Roles('SUPER_ADMIN')
  grantRole(@Param('id') id: string, @Body() body: { role: string }, @CurrentUser() user: any) {
    return this.service.grantRole(id, body.role, user.sub);
  }
}
