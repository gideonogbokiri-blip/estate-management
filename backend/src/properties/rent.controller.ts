import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { RentService } from './rent.service.js';

@Controller('estate/estates/:estateId/rent')
@UseGuards(AccessTokenGuard)
export class RentController {
  constructor(private readonly rent: RentService) {}

  @Post('generate')
  generate(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Body() body: { from?: string; months?: number }) {
    return this.rent.generate(request.actor.userId, estateId, body.from, body.months ?? 3);
  }

  @Get('schedule')
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Query('tenantUserId') tenantUserId?: string, @Query('payeeUserId') payeeUserId?: string) {
    return this.rent.list(request.actor.userId, estateId, { tenantUserId, payeeUserId });
  }

  @Get('landlord-summary')
  landlordSummary(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.rent.landlordSummary(request.actor.userId, estateId);
  }
}
