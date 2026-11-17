import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { PlatformAccountsQueryDto, PlatformAdjustmentDto, PlatformAdjustmentsQueryDto } from './platform-money.dto.js';
import { PlatformMoneyService } from './platform-money.service.js';

@Controller('platform/admin/money')
@UseGuards(AccessTokenGuard)
export class PlatformMoneyController {
  constructor(private readonly money: PlatformMoneyService) {}

  @Get('overview')
  overview(@Req() req: AuthenticatedRequest) {
    return this.money.overview(req.actor.userId);
  }

  @Get('estates/:estateId/accounts')
  accounts(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Query() query: PlatformAccountsQueryDto) {
    return this.money.accounts(req.actor.userId, estateId, query);
  }

  @Post('estates/:estateId/accounts/:userId/adjustments')
  adjust(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('userId', ParseUUIDPipe) userId: string, @Headers('idempotency-key') key: string | undefined,
    @Body() body: PlatformAdjustmentDto) {
    return this.money.createAdjustment(req.actor.userId, estateId, userId, body, key);
  }

  @Get('estates/:estateId/accounts/:userId/adjustments')
  adjustments(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('userId', ParseUUIDPipe) userId: string, @Query() query: PlatformAdjustmentsQueryDto) {
    return this.money.adjustments(req.actor.userId, estateId, userId, query);
  }
}
