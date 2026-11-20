import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { AddHouseholdMemberDto, DecideHouseholdMemberDto, EndHouseholdMemberDto } from './household.dto.js';
import { HouseholdService } from './household.service.js';

@Controller('estate/estates/:estateId/household')
@UseGuards(AccessTokenGuard)
export class HouseholdController {
  constructor(private readonly household: HouseholdService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Query('propertyId') propertyId?: string, @Query('status') status?: string, @Query('primaryUserId') primaryUserId?: string) {
    return this.household.listForEstate(request.actor.userId, estateId, { propertyId, status, primaryUserId });
  }

  @Post()
  add(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Body() body: AddHouseholdMemberDto) {
    return this.household.add(request.actor.userId, estateId, body);
  }

  @Post(':memberId/decide')
  decide(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('memberId', ParseUUIDPipe) memberId: string, @Body() body: DecideHouseholdMemberDto) {
    return this.household.decide(request.actor.userId, estateId, memberId, body);
  }

  @Post(':memberId/end')
  end(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('memberId', ParseUUIDPipe) memberId: string, @Body() body: EndHouseholdMemberDto) {
    return this.household.end(request.actor.userId, estateId, memberId, body);
  }
}

@Controller('estate/household/mine')
@UseGuards(AccessTokenGuard)
export class MyHouseholdController {
  constructor(private readonly household: HouseholdService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest) {
    return this.household.listMine(request.actor.userId);
  }
}
