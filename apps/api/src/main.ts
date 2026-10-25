import { NestFactory } from '@nestjs/core';
import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ExpressAdapter } from '@nestjs/platform-express';
import { AppModule } from './app.module.js';
import { HttpExceptionFilter } from './common/filters/http-exception.filter.js';
import { AppLogger } from './logger/logger.service.js';
import { RequestIdInterceptor } from './common/interceptors/request-id.interceptor.js';
import { ConfigModule } from './config/config.module.js';

async function bootstrap() {
  // ConfigModule validates env eagerly on import; this also confirms required vars.
  await import('./config/config.module.js');

  const app = await NestFactory.create(AppModule, new ExpressAdapter(), {
    bufferLogs: true,
    logger: new AppLogger(),
    cors: {
      origin: (process.env.CORS_ORIGIN ?? 'http://localhost:3000').split(',').map((o) => o.trim()),
      credentials: true,
    },
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      exceptionFactory: (errors) => {
        const first = errors[0];
        const constraints = first ? Object.values(first.constraints ?? {}) : [];
        return new BadRequestException(constraints.join('; ') || 'Validation failed');
      },
    }),
  );

  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new RequestIdInterceptor());

  app.setGlobalPrefix('/v1');

  const config = new DocumentBuilder()
    .setTitle('Mishwar Yemen API')
    .setDescription('Ride-hailing platform API (v1). واجهة برمجة تطبيقات منصة مشوار اليمن.')
    .setVersion('1.0')
    .addBearerAuth(
      { type: 'http', scheme: 'bearer', bearerFormat: 'JWT', name: 'JWT', in: 'header' },
      'access-token',
    )
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('/docs', app, document);

  const port = Number(process.env.PORT ?? 4000);
  await app.listen(port);
  // eslint-disable-next-line no-console
  console.log(`Mishwar API listening on :${port} (env=${process.env.NODE_ENV})`);
}

bootstrap().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('Failed to bootstrap application', err);
  process.exit(1);
});
