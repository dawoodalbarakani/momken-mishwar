import { Module, Global } from '@nestjs/common';
import { ConfigModule as NestConfigModule } from '@nestjs/config';
import { validateConfig, configuration } from './configuration.js';

@Global()
@Module({
  imports: [
    NestConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env'],
      expandVariables: true,
      ignoreEnvFile: process.env.NODE_ENV === 'production',
      validate: (env) => validateConfig(env),
      load: [configuration],
    }),
  ],
  exports: [NestConfigModule],
})
export class ConfigModule {}
