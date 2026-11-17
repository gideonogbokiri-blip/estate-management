import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { PropertiesService } from './properties.service.js';
import { CreateResidentJoinRequestDto, DecideResidentJoinRequestDto, ResidentJoinRequestQueryDto } from './resident-requests.dto.js';

@Controller('estate')
@UseGuards(AccessTokenGuard)
export class ResidentRequestsController {
  constructor(private readonly properties: PropertiesService) {}

  @Post('residents/join-requests')
  create(@Req() request: AuthenticatedRequest, @Body() body: CreateResidentJoinRequestDto) {
    return this.properties.createResidentJoinRequest(request.actor.userId, body);
  }

  @Get('residents/join-requests/mine')
  mine(@Req() request: AuthenticatedRequest, @Query() query: ResidentJoinRequestQueryDto) {
    return this.properties.listMyResidentJoinRequests(request.actor.userId, query);
  }

  @Get('residents/join-requests/:requestId')
  detail(@Req() request: AuthenticatedRequest, @Param('requestId', ParseUUIDPipe) requestId: string) {
    return this.properties.readResidentJoinRequest(request.actor.userId, requestId);
  }

  @Get('estates/:estateId/resident-requests')
  queue(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Query() query: ResidentJoinRequestQueryDto) {
    return this.properties.listResidentJoinRequests(request.actor.userId, estateId, query);
  }

  @Post('estates/:estateId/resident-requests/:requestId/approve')
  approve(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('requestId', ParseUUIDPipe) requestId: string, @Body() body: DecideResidentJoinRequestDto) {
    return this.properties.decideResidentJoinRequest(request.actor.userId, estateId, requestId, 'approve', body.reason);
  }

  @Post('estates/:estateId/resident-requests/:requestId/reject')
  reject(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('requestId', ParseUUIDPipe) requestId: string, @Body() body: DecideResidentJoinRequestDto) {
    return this.properties.decideResidentJoinRequest(request.actor.userId, estateId, requestId, 'reject', body.reason);
  }
}
