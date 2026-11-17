import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateEstateAnnouncementDto } from './announcements.dto.js';
import { EstateAnnouncementsService } from './announcements.service.js';

@Controller('estate/estates/:estateId/announcements')
@UseGuards(AccessTokenGuard)
export class EstateAnnouncementsController {
  constructor(private readonly announcements: EstateAnnouncementsService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.announcements.listForStaff(request.actor.userId, estateId);
  }

  @Post()
  createDraft(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateEstateAnnouncementDto) {
    return this.announcements.createDraft(request.actor.userId, estateId, body);
  }

  @Post(':announcementId/publish')
  publish(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('announcementId', ParseUUIDPipe) announcementId: string) {
    return this.announcements.publish(request.actor.userId, estateId, announcementId);
  }
}

@Controller('estate/announcements')
@UseGuards(AccessTokenGuard)
export class ResidentAnnouncementsController {
  constructor(private readonly announcements: EstateAnnouncementsService) {}

  @Get('mine')
  listMine(@Req() request: AuthenticatedRequest) {
    return this.announcements.listMine(request.actor.userId);
  }

  @Post(':announcementId/read')
  markRead(@Req() request: AuthenticatedRequest, @Param('announcementId', ParseUUIDPipe) announcementId: string) {
    return this.announcements.markRead(request.actor.userId, announcementId);
  }
}
