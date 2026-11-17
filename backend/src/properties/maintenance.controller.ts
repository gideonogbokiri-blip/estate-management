import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateMaintenanceRequestDto, MaintenanceQueueQueryDto, MyMaintenanceQueryDto, ReviewMaintenanceRequestDto } from './maintenance.dto.js';
import { MaintenanceService } from './maintenance.service.js';

@Controller('estate')
@UseGuards(AccessTokenGuard)
export class MaintenanceController {
  constructor(private readonly maintenance: MaintenanceService) {}

  @Post('maintenance/requests')
  create(@Req() request: AuthenticatedRequest, @Headers('idempotency-key') idempotencyKey: string | undefined, @Body() body: CreateMaintenanceRequestDto) {
    return this.maintenance.create(request.actor.userId, body, idempotencyKey);
  }

  @Get('maintenance/requests/mine')
  mine(@Req() request: AuthenticatedRequest, @Query() query: MyMaintenanceQueryDto) {
    return this.maintenance.listMine(request.actor.userId, query.estateId, query.page, query.pageSize);
  }

  @Get('estates/:estateId/maintenance/requests')
  queue(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Query() query: MaintenanceQueueQueryDto) {
    return this.maintenance.listQueue(request.actor.userId, estateId, query);
  }

  @Post('estates/:estateId/maintenance/requests/:requestId/review')
  review(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('requestId', ParseUUIDPipe) requestId: string, @Body() body: ReviewMaintenanceRequestDto) {
    return this.maintenance.review(request.actor.userId, estateId, requestId, body);
  }
}