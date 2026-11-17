import { Controller, Get, Param, ParseUUIDPipe, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { EstateDashboardService } from './estate-dashboard.service.js';

@Controller('estate/estates/:estateId/dashboard')
@UseGuards(AccessTokenGuard)
export class EstateDashboardController {
  constructor(private readonly dashboard: EstateDashboardService) {}

  @Get()
  summary(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.dashboard.summary(request.actor.userId, estateId);
  }
}
