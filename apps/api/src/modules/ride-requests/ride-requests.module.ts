import { Module } from '@nestjs/common';
import { RideRequestsController } from './ride-requests.controller.js';
import { RideRequestsService } from './ride-requests.service.js';
import { PricingModule } from '../pricing/pricing.module.js';

@Module({
  imports: [PricingModule],
  controllers: [RideRequestsController],
  providers: [RideRequestsService],
  exports: [RideRequestsService],
})
export class RideRequestsModule {}
