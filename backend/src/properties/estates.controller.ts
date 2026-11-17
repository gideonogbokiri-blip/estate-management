import { Controller, Get, Param, ParseUUIDPipe, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { PropertiesService } from './properties.service.js';

@Controller('estate/estates')
@UseGuards(AccessTokenGuard)
export class EstatesController {
  constructor(private readonly properties: PropertiesService) {}

  @Get('mine')
  listMine(@Req() request: AuthenticatedRequest) {
    return this.properties.listMyEstates(request.actor.userId);
  }

  @Get('management')
  listManagement(@Req() request: AuthenticatedRequest) {
    return this.properties.listMyManagementEstates(request.actor.userId);
  }

  @Get('available')
  listAvailable() {
    return this.properties.listAvailableEstates();
  }

  @Get(':estateId/join-properties')
  listJoinProperties(@Param('estateId', new ParseUUIDPipe()) estateId: string) {
    return this.properties.listJoinRequestProperties(estateId);
  }
}
