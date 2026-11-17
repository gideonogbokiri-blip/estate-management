import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthModule } from './health/health.module.js';
import { AuthModule } from './auth/auth.module.js';
import { ApplicationsModule } from './applications/applications.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { PlatformApplicationsModule } from './platform-applications/platform-applications.module.js';
import { PropertiesModule } from './properties/properties.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
    PrismaModule,
    AuthModule,
    ApplicationsModule,
    PlatformApplicationsModule,
    PropertiesModule,
    HealthModule,
  ],
})
export class AppModule {}
