import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import {
  CreateOwnershipInterestDto,
  DecideOwnershipVerificationDto,
  EndOwnershipInterestDto,
  OwnershipQueryDto,
} from './ownership.dto.js';
import { OwnershipService } from './ownership.service.js';

@Controller('estate/estates/:estateId')
@UseGuards(AccessTokenGuard)
export class OwnershipController {
  constructor(private readonly ownership: OwnershipService) {}

  @Get('ownership')
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Query() query: OwnershipQueryDto) {
    return this.ownership.list(request.actor.userId, estateId, query);
  }

  @Get('properties/:propertyId/owners')
  propertyOwners(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('propertyId', ParseUUIDPipe) propertyId: string) {
    return this.ownership.listPropertyOwners(request.actor.userId, estateId, propertyId);
  }

  @Post('properties/:propertyId/owners')
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('propertyId', ParseUUIDPipe) propertyId: string, @Body() body: CreateOwnershipInterestDto) {
    return this.ownership.create(request.actor.userId, estateId, propertyId, body);
  }

  @Post('ownership/:ownershipId/verify')
  decide(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('ownershipId', ParseUUIDPipe) ownershipId: string, @Body() body: DecideOwnershipVerificationDto) {
    return this.ownership.decide(request.actor.userId, estateId, ownershipId, body);
  }

  @Post('ownership/:ownershipId/end')
  end(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('ownershipId', ParseUUIDPipe) ownershipId: string, @Body() body: EndOwnershipInterestDto) {
    return this.ownership.end(request.actor.userId, estateId, ownershipId, body);
  }
}

@Controller('estate/estates/:estateId/landlord')
@UseGuards(AccessTokenGuard)
export class LandlordPortfolioController {
  constructor(private readonly ownership: OwnershipService) {}

  @Get('portfolio')
  portfolio(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.ownership.landlordPortfolio(request.actor.userId, estateId);
  }
}

@Controller('estate/landlord')
@UseGuards(AccessTokenGuard)
export class LandlordEstatesController {
  constructor(private readonly ownership: OwnershipService) {}

  @Get('estates/mine')
  estates(@Req() request: AuthenticatedRequest) {
    return this.ownership.myLandlordEstates(request.actor.userId);
  }
}

