import { Module } from '@nestjs/common';
import { DriverWalletController } from './driver-wallet.controller.js';
import { DriverWalletService } from './driver-wallet.service.js';

@Module({
  controllers: [DriverWalletController],
  providers: [DriverWalletService],
  exports: [DriverWalletService],
})
export class DriverWalletModule {}
