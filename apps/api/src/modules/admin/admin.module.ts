import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller.js';
import { AdminService } from './admin.service.js';
import { DriverVerificationModule } from '../driver-verification/driver-verification.module.js';
import { DriverWalletModule } from '../driver-wallet/driver-wallet.module.js';
import { PaymentsModule } from '../payments/payments.module.js';

@Module({
  imports: [DriverVerificationModule, DriverWalletModule, PaymentsModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
