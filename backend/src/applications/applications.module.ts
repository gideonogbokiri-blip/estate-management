import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { PrivateDocumentsModule } from '../private-documents/private-documents.module.js';
import { ApplicationsController } from './applications.controller.js';
import { ApplicationsService } from './applications.service.js';

@Module({
  imports: [AuthModule, PrivateDocumentsModule],
  controllers: [ApplicationsController],
  providers: [ApplicationsService],
})
export class ApplicationsModule {}
