import { Controller, Get, Param, ParseUUIDPipe, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { ManagerResidentsService } from './manager-residents.service.js';

@Controller('estate/estates/:estateId/manager')
@UseGuards(AccessTokenGuard)
export class ManagerResidentsController {
  constructor(private readonly residents: ManagerResidentsService) {}

  @Get('residents')
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.residents.listResidents(request.actor.userId, estateId);
  }

  @Get('residents/:residentUserId/history')
  history(
    @Req() request: AuthenticatedRequest,
    @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('residentUserId', ParseUUIDPipe) residentUserId: string,
  ) {
    return this.residents.residentHistory(request.actor.userId, estateId, residentUserId);
  }
}
