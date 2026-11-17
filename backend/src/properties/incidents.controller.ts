import { Body, Controller, Get, Headers, Header, Param, ParseUUIDPipe, Post, Req, StreamableFile, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateSecurityIncidentDto, ReviewSecurityIncidentDto } from './incidents.dto.js';
import { SecurityIncidentsService } from './incidents.service.js';

@Controller('estate/estates/:estateId/security-incidents')
@UseGuards(AccessTokenGuard)
export class SecurityIncidentsController {
  constructor(private readonly incidents: SecurityIncidentsService) {}

  @Post()
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateSecurityIncidentDto) {
    return this.incidents.create(request.actor.userId, estateId, body);
  }

  @Get('mine')
  mine(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.incidents.mine(request.actor.userId, estateId);
  }

  @Get()
  queue(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.incidents.queue(request.actor.userId, estateId);
  }

  @Post(':incidentId/review')
  review(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('incidentId', ParseUUIDPipe) incidentId: string, @Body() body: ReviewSecurityIncidentDto) {
    return this.incidents.review(request.actor.userId, estateId, incidentId, body);
  }

  @Post(':incidentId/evidence')
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { files: 1, fileSize: 10 * 1024 * 1024 } }))
  uploadEvidence(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('incidentId', ParseUUIDPipe) incidentId: string, @UploadedFile() file: Express.Multer.File,
    @Headers('idempotency-key') idempotencyKey: string | undefined) {
    return this.incidents.uploadEvidence(request.actor.userId, estateId, incidentId, file, idempotencyKey);
  }

  @Get(':incidentId/evidence/:evidenceId/content')
  @Header('Cache-Control', 'private, no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  async downloadEvidence(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('incidentId', ParseUUIDPipe) incidentId: string, @Param('evidenceId', ParseUUIDPipe) evidenceId: string) {
    const file = await this.incidents.readEvidence(request.actor.userId, estateId, incidentId, evidenceId);
    return new StreamableFile(file.content, { type: file.contentType, length: file.content.length,
      disposition: `attachment; filename="incident-evidence.${file.extension}"` });
  }
}
