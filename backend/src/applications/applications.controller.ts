import {
  Body,
  Headers,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Header,
  Req,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
  UseGuards,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { ApplicationsService } from './applications.service.js';
import { UpdateApplicationDraftDto, UploadApplicationDocumentDto } from './applications.dto.js';

@Controller('estate/applications')
@UseGuards(AccessTokenGuard)
export class ApplicationsController {
  constructor(private readonly applications: ApplicationsService) {}

  @Post()
  createDraft(@Req() request: AuthenticatedRequest) {
    return this.applications.createDraft(request.actor.userId);
  }

  @Get('mine')
  listMine(@Req() request: AuthenticatedRequest) {
    return this.applications.listMine(request.actor.userId);
  }

  @Patch(':applicationId')
  updateDraft(
    @Req() request: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
    @Body() body: UpdateApplicationDraftDto,
  ) {
    return this.applications.updateDraft(
      request.actor.userId,
      applicationId,
      body,
    );
  }

  @Post(':applicationId/submit')
  submit(
    @Req() request: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
  ) {
    return this.applications.submit(request.actor.userId, applicationId);
  }

  @Get(':applicationId/documents')
  listApplicantDocuments(
    @Req() request: AuthenticatedRequest,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
  ) {
    return this.applications.listApplicantDocuments(request.actor.userId, applicationId);
  }

  @Post(':applicationId/documents')
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { files: 1, fileSize: 10 * 1024 * 1024 } }))
  uploadDocument(
    @Req() request: AuthenticatedRequest,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
    @Body() body: UploadApplicationDocumentDto,
    @UploadedFile() file: Express.Multer.File,
    @Headers('idempotency-key') idempotencyKey: string | undefined,
  ) {
    return this.applications.uploadDocument(request.actor.userId, applicationId, body, file, idempotencyKey);
  }

  @Get(':applicationId/documents/:documentId/content')
  @Header('Cache-Control', 'private, no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  async downloadApplicantDocument(
    @Req() request: AuthenticatedRequest,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
    @Param('documentId', ParseUUIDPipe) documentId: string,
  ) {
    const file = await this.applications.readApplicantDocument(request.actor.userId, applicationId, documentId);
    return new StreamableFile(file.content, { type: file.contentType, length: file.content.length, disposition: `attachment; filename="supporting-document.${file.extension}"` });
  }
}
