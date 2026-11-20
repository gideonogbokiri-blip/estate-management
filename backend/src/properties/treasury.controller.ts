import { Controller, Get, Param, ParseUUIDPipe, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { EstateTreasuryService } from './treasury.service.js';

@Controller('estate/estates/:estateId/treasury')
@UseGuards(AccessTokenGuard)
export class EstateTreasuryController {
  constructor(private readonly treasury: EstateTreasuryService) {}

  @Get('summary')
  summary(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.treasury.summary(request.actor.userId, estateId);
  }
}
