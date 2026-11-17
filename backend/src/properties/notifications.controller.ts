import { Controller, Get, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { EstateNotificationsService } from './notifications.service.js';

@Controller('notifications')
@UseGuards(AccessTokenGuard)
export class EstateNotificationsController {
  constructor(private readonly notifications: EstateNotificationsService) {}

  @Get('mine')
  listMine(@Req() request: AuthenticatedRequest) {
    return this.notifications.listMine(request.actor.userId);
  }

  @Post(':notificationId/read')
  markRead(@Req() request: AuthenticatedRequest, @Param('notificationId', ParseUUIDPipe) notificationId: string) {
    return this.notifications.markRead(request.actor.userId, notificationId);
  }
}
