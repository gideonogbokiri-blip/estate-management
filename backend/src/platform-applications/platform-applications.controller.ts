import {
  Body,
  Header,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import {
  ApproveApplicationDto,
  AssignReviewerDto,
  DecisionReasonDto,
  QueueQueryDto,
} from './platform-applications.dto.js';
import { PlatformApplicationsService } from './platform-applications.service.js';

@Controller('platform/applications')
@UseGuards(AccessTokenGuard)
export class PlatformApplicationsController {
  constructor(private readonly service: PlatformApplicationsService) {}

  @Get('initial-administrators')
  initialAdministrators(@Req() req: AuthenticatedRequest) {
    return this.service.initialAdministrators(req.actor.userId);
  }

  @Get()
  queue(@Req() req: AuthenticatedRequest, @Query() query: QueueQueryDto) {
    return this.service.queue(req.actor.userId, query);
  }

  @Get(':applicationId')
  detail(
    @Req() req: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
  ) {
    return this.service.detail(req.actor.userId, applicationId);
  }

  @Get(':applicationId/documents/:documentId/content')
  @Header('Cache-Control', 'private, no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  async downloadApplicationDocument(
    @Req() req: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
    @Param('documentId', new ParseUUIDPipe()) documentId: string,
  ) {
    const file = await this.service.readApplicationDocument(req.actor.userId, applicationId, documentId);
    return new StreamableFile(file.content, { type: file.contentType, length: file.content.length, disposition: `attachment; filename="application-document.${file.extension}"` });
  }

  @Post(':applicationId/start-review')
  startReview(
    @Req() req: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
  ) {
    return this.service.startReview(req.actor.userId, applicationId);
  }

  @Post(':applicationId/assign')
  assign(
    @Req() req: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
    @Body() body: AssignReviewerDto,
  ) {
    return this.service.assignReviewer(req.actor.userId, applicationId, body.reviewerUserId);
  }

  @Post(':applicationId/request-information')
  requestInformation(
    @Req() req: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
    @Body() body: DecisionReasonDto,
  ) {
    return this.service.decide(req.actor.userId, applicationId, 'request_information', body.reason);
  }

  @Post(':applicationId/reject')
  reject(
    @Req() req: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
    @Body() body: DecisionReasonDto,
  ) {
    return this.service.decide(req.actor.userId, applicationId, 'reject', body.reason);
  }

  @Post(':applicationId/approve')
  approve(
    @Req() req: AuthenticatedRequest,
    @Param('applicationId', new ParseUUIDPipe()) applicationId: string,
    @Body() body: ApproveApplicationDto,
  ) {
    return this.service.approve(req.actor.userId, applicationId, body.initialAdministratorUserId);
  }
}
