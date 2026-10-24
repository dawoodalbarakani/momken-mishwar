import { Module } from '@nestjs/common';
import { DriverVerificationController } from './driver-verification.controller.js';
import { DriverVerificationService } from './driver-verification.service.js';

@Module({
  controllers: [DriverVerificationController],
  providers: [DriverVerificationService],
})
export class DriverVerificationModule {}
