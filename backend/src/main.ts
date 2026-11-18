import 'reflect-metadata';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module.js';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService);
  const configuredOrigins = config
    .getOrThrow<string>('APP_ORIGINS')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const origins = configuredOrigins.map((origin) => {
    const parsed = new URL(origin);
    if (!['http:', 'https:'].includes(parsed.protocol) || parsed.origin !== origin) {
      throw new Error('APP_ORIGINS must contain only exact HTTP or HTTPS origins.');
    }
    return parsed.origin;
  });

  app.use(helmet());
  app.use((request: { method?: string; originalUrl?: string }, response: { statusCode: number; on: (event: string, listener: () => void) => void }, next: () => void) => {
    const started = Date.now();
    response.on('finish', () => {
      Logger.log(
        `${request.method ?? 'GET'} ${request.originalUrl ?? '/'} ${response.statusCode} ${Date.now() - started}ms`,
        'HTTP',
      );
    });
    next();
  });
  app.enableCors({
    origin: origins,
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
  });
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: false },
    }),
  );
  app.enableShutdownHooks();

  const port = Number(config.get<string>('PORT') ?? 4100);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('PORT must be a valid TCP port between 1 and 65535.');
  }
  await app.listen(port, '0.0.0.0');
}

void bootstrap();
