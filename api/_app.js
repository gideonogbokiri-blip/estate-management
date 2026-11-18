require('../backend/node_modules/reflect-metadata');
const { NestFactory } = require('../backend/node_modules/@nestjs/core');
const { ValidationPipe } = require('../backend/node_modules/@nestjs/common');
const helmetModule = require('../backend/node_modules/helmet');
const { AppModule } = require('../backend/dist/src/app.module.js');

let appPromise;

function configuredOrigins() {
  const origins = (process.env.APP_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (process.env.VERCEL_URL) origins.push(`https://${process.env.VERCEL_URL}`);
  if (origins.length === 0) origins.push('http://localhost:8765', 'http://127.0.0.1:8765');
  return origins;
}

async function getApp() {
  if (!appPromise) {
    appPromise = (async () => {
      const app = await NestFactory.create(AppModule, {
        logger: ['error', 'warn'],
        bodyParser: true,
      });
      const express = require('../backend/node_modules/express');
      app.use('/api/v1/payments/paystack/webhook', express.raw({ type: '*/*' }));
      const helmet = helmetModule.default ?? helmetModule;
      app.use(helmet());
      app.use((request, response, next) => {
        const started = Date.now();
        response.on('finish', () => {
          console.log(JSON.stringify({
            at: new Date().toISOString(),
            method: request.method,
            path: request.originalUrl,
            status: response.statusCode,
            durationMs: Date.now() - started,
          }));
        });
        next();
      });
      app.enableCors({ origin: configuredOrigins(), credentials: true });
      app.useGlobalPipes(
        new ValidationPipe({
          whitelist: true,
          forbidNonWhitelisted: true,
          transform: true,
          transformOptions: { enableImplicitConversion: false },
        }),
      );
      app.setGlobalPrefix('api/v1');
      await app.init();
      return app;
    })().catch((error) => {
      appPromise = undefined;
      throw error;
    });
  }
  return appPromise;
}

module.exports = { getApp };
