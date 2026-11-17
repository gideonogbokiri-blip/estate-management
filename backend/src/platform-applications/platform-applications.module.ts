import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { PrivateDocumentsModule } from '../private-documents/private-documents.module.js';
import { PlatformApplicationsController } from './platform-applications.controller.js';
import { PlatformApplicationsService } from './platform-applications.service.js';
import { PlatformAdminController } from './platform-admin.controller.js';
import { PlatformAdminService } from './platform-admin.service.js';

@Module({
  imports: [AuthModule, PrivateDocumentsModule],
  controllers: [PlatformApplicationsController, PlatformAdminController],
  providers: [PlatformApplicationsService, PlatformAdminService],
})
export class PlatformApplicationsModule {}
