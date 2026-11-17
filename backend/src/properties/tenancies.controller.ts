import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { ApproveTenancyDto, CreateTenancyDto, RentSchedulePreviewQueryDto, TenancyQueryDto, TerminateTenancyDto } from './tenancies.dto.js';
import { TenanciesService } from './tenancies.service.js';

@Controller('estate/estates/:estateId')
@UseGuards(AccessTokenGuard)
export class TenanciesController {
  constructor(private readonly tenancies: TenanciesService) {}

  @Get('tenancies')
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Query() query: TenancyQueryDto) {
    return this.tenancies.list(request.actor.userId, estateId, query);
  }

  @Get('rent-schedule-preview')
  previewRentSchedule(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Query() query: RentSchedulePreviewQueryDto) {
    return this.tenancies.previewRentSchedule(request.actor.userId, estateId, query.year, query.month);
  }

  @Post('properties/:propertyId/tenancies')
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('propertyId', ParseUUIDPipe) propertyId: string, @Body() body: CreateTenancyDto) {
    return this.tenancies.create(request.actor.userId, estateId, propertyId, body);
  }

  @Post('tenancies/:tenancyId/approve')
  approve(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('tenancyId', ParseUUIDPipe) tenancyId: string, @Body() body: ApproveTenancyDto) {
    return this.tenancies.approve(request.actor.userId, estateId, tenancyId, body);
  }

  @Post('tenancies/:tenancyId/terminate')
  terminate(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('tenancyId', ParseUUIDPipe) tenancyId: string, @Body() body: TerminateTenancyDto) {
    return this.tenancies.terminate(request.actor.userId, estateId, tenancyId, body);
  }
}
