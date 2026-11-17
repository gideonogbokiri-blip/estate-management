import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateEstateFacilityDto, CreateFacilityBookingDto, ReviewFacilityBookingDto } from './facilities.dto.js';
import { EstateFacilitiesService } from './facilities.service.js';

@Controller('estate/estates/:estateId')
@UseGuards(AccessTokenGuard)
export class EstateFacilitiesController {
  constructor(private readonly facilities: EstateFacilitiesService) {}

  @Get('facilities')
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.facilities.list(request.actor.userId, estateId);
  }

  @Post('facilities')
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateEstateFacilityDto) {
    return this.facilities.create(request.actor.userId, estateId, body);
  }

  @Get('facilities/:facilityId/availability')
  availability(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('facilityId', ParseUUIDPipe) facilityId: string, @Query('date') date: string) {
    return this.facilities.availability(request.actor.userId, estateId, facilityId, date);
  }

  @Post('facilities/:facilityId/bookings')
  book(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('facilityId', ParseUUIDPipe) facilityId: string, @Headers('idempotency-key') key: string | undefined,
    @Body() body: CreateFacilityBookingDto) {
    return this.facilities.createBooking(request.actor.userId, estateId, facilityId, body, key);
  }

  @Get('facility-bookings/mine')
  mine(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.facilities.mine(request.actor.userId, estateId);
  }

  @Get('facility-bookings')
  queue(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.facilities.queue(request.actor.userId, estateId);
  }

  @Post('facility-bookings/:bookingId/review')
  review(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('bookingId', ParseUUIDPipe) bookingId: string, @Body() body: ReviewFacilityBookingDto) {
    return this.facilities.review(request.actor.userId, estateId, bookingId, body);
  }

  @Post('facility-bookings/:bookingId/cancel')
  cancel(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('bookingId', ParseUUIDPipe) bookingId: string) {
    return this.facilities.cancel(request.actor.userId, estateId, bookingId);
  }
}
