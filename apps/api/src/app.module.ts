import { Module } from '@nestjs/common';
import { ConfigModule } from './config/config.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { AuthModule } from './modules/auth/auth.module.js';
import { UsersModule } from './modules/users/users.module.js';
import { CustomersModule } from './modules/customers/customers.module.js';
import { DriversModule } from './modules/drivers/drivers.module.js';
import { VehiclesModule } from './modules/vehicles/vehicles.module.js';
import { DriverVerificationModule } from './modules/driver-verification/driver-verification.module.js';
import { ServiceAreasModule } from './modules/service-areas/service-areas.module.js';
import { PricingModule } from './modules/pricing/pricing.module.js';
import { RideRequestsModule } from './modules/ride-requests/ride-requests.module.js';
import { DispatchModule } from './modules/dispatch/dispatch.module.js';
import { TripsModule } from './modules/trips/trips.module.js';
import { DriverLocationsModule } from './modules/driver-locations/driver-locations.module.js';
import { PaymentsModule } from './modules/payments/payments.module.js';
import { DriverWalletModule } from './modules/driver-wallet/driver-wallet.module.js';
import { RatingsModule } from './modules/ratings/ratings.module.js';
import { NotificationsModule } from './modules/notifications/notifications.module.js';
import { SupportModule } from './modules/support/support.module.js';
import { AdminModule } from './modules/admin/admin.module.js';
import { AuditLogsModule } from './modules/audit-logs/audit-logs.module.js';
import { HealthModule } from './modules/health/health.module.js';

@Module({
  imports: [
    ConfigModule,
    PrismaModule,
    AuthModule,
    UsersModule,
    CustomersModule,
    DriversModule,
    VehiclesModule,
    DriverVerificationModule,
    ServiceAreasModule,
    PricingModule,
    RideRequestsModule,
    DispatchModule,
    TripsModule,
    DriverLocationsModule,
    PaymentsModule,
    DriverWalletModule,
    RatingsModule,
    NotificationsModule,
    SupportModule,
    AdminModule,
    AuditLogsModule,
    HealthModule,
  ],
})
export class AppModule {}
