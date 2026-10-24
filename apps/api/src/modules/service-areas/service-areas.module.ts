import { Module } from '@nestjs/common';
import { ServiceAreasController } from './service-areas.controller.js';
import { ServiceAreasService } from './service-areas.service.js';

@Module({
  controllers: [ServiceAreasController],
  providers: [ServiceAreasService],
})
export class ServiceAreasModule {}
