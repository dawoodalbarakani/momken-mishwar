import { Module } from '@nestjs/common';
import { DispatchController } from './dispatch.controller.js';
import { DispatchService } from './dispatch.service.js';
import { DispatchSweeperService } from './dispatch-sweeper.service.js';
import { RideRequestsModule } from '../ride-requests/ride-requests.module.js';

@Module({
  imports: [RideRequestsModule],
  controllers: [DispatchController],
  providers: [DispatchService, DispatchSweeperService],
  exports: [DispatchService],
})
export class DispatchModule {}
