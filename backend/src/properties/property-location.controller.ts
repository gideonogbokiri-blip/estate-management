import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CapturePropertyLocationDto, VerifyPropertyLocationDto } from './property-location.dto.js';
import { PropertyLocationService } from './property-location.service.js';

@Controller('estate/estates/:estateId/properties/locations')
@UseGuards(AccessTokenGuard)
export class PropertyLocationController {
  constructor(private readonly locations: PropertyLocationService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.locations.list(request.actor.userId, estateId);
  }
}

@Controller('estate/estates/:estateId/properties/:propertyId/location')
@UseGuards(AccessTokenGuard)
export class PropertyLocationActionController {
  constructor(private readonly locations: PropertyLocationService) {}

  @Post()
  capture(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('propertyId', ParseUUIDPipe) propertyId: string, @Body() body: CapturePropertyLocationDto) {
    return this.locations.capture(request.actor.userId, estateId, propertyId, body);
  }

  @Post('verify')
  verify(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('propertyId', ParseUUIDPipe) propertyId: string, @Body() body: VerifyPropertyLocationDto) {
    return this.locations.verify(request.actor.userId, estateId, propertyId, body);
  }
}
