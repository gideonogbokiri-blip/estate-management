import { Module } from '@nestjs/common';
import { PrivateDocumentsService } from './private-documents.service.js';

@Module({ providers: [PrivateDocumentsService], exports: [PrivateDocumentsService] })
export class PrivateDocumentsModule {}
