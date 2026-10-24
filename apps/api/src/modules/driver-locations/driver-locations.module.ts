import { Module } from '@nestjs/common';
import { DriverLocationsController } from './driver-locations.controller.js';
import { DriverLocationsService } from './driver-locations.service.js';

@Module({
  controllers: [DriverLocationsController],
  providers: [DriverLocationsService],
})
export class DriverLocationsModule {}
