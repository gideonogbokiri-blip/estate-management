import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateVisitorPassDto, MyVisitorPassesQueryDto, RevokeVisitorPassDto } from './visitor-passes.dto.js';
import { VisitorPassesService } from './visitor-passes.service.js';

@Controller('estate/visitor-passes')
@UseGuards(AccessTokenGuard)
export class VisitorPassesController {
  constructor(private readonly visitorPasses: VisitorPassesService) {}

  @Get('mine')
  mine(@Req() request: AuthenticatedRequest, @Query() query: MyVisitorPassesQueryDto) {
    return this.visitorPasses.listMine(request.actor.userId, query.estateId);
  }

  @Get('properties')
  properties(@Req() request: AuthenticatedRequest, @Query() query: MyVisitorPassesQueryDto) {
    return this.visitorPasses.listMyProperties(request.actor.userId, query.estateId);
  }

  @Post()
  create(@Req() request: AuthenticatedRequest, @Headers('idempotency-key') key: string | undefined, @Body() body: CreateVisitorPassDto) {
    return this.visitorPasses.create(request.actor.userId, body, key);
  }

  @Post(':passId/revoke')
  revoke(@Req() request: AuthenticatedRequest, @Query() query: MyVisitorPassesQueryDto,
    @Body() body: RevokeVisitorPassDto, @Param('passId', ParseUUIDPipe) passId: string) {
    return this.visitorPasses.revoke(request.actor.userId, query.estateId, passId, body.reason);
  }
}
