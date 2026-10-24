import {
  Controller,
  Get,
  Post,
  Put,
  Body,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ServiceAreasService } from './service-areas.service.js';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard.js';
import { Roles } from '../../common/decorators/roles.decorator.js';

@ApiTags('ServiceAreas')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard)
@Controller('service-areas')
export class ServiceAreasController {
  constructor(private readonly service: ServiceAreasService) {}

  @Get()
  @ApiOperation({ summary: 'List active service areas' })
  list() {
    return this.service.list();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a service area' })
  get(@Param('id') id: string) {
    return this.service.get(id);
  }

  @Post()
  @ApiOperation({ summary: 'Create a service area' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER')
  create(@Body() body: any) {
    return this.service.create(body);
  }

  @Put(':id')
  @ApiOperation({ summary: 'Update a service area' })
  @Roles('ADMIN', 'SUPER_ADMIN', 'OPERATIONS_MANAGER')
  update(@Param('id') id: string, @Body() body: any) {
    return this.service.update(id, body);
  }

  @Get('coverage')
  @ApiOperation({ summary: 'Check whether a point is covered by a service area' })
  coverage(@Query() q: { lat: number; lon: number }) {
    return this.service.coverageCheck(Number(q.lat), Number(q.lon));
  }
}
