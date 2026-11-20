import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { DecideIdentityVerificationDto, SubmitIdentityVerificationDto } from './identity.dto.js';
import { IdentityService } from './identity.service.js';

@Controller('estate/estates/:estateId/identity')
@UseGuards(AccessTokenGuard)
export class IdentityController {
  constructor(private readonly identity: IdentityService) {}

  @Post('verifications')
  submit(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Body() body: SubmitIdentityVerificationDto) {
    return this.identity.submit(request.actor.userId, estateId, body);
  }

  @Get('verifications/mine')
  mine(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.identity.listMine(request.actor.userId, estateId);
  }

  @Get('verifications')
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.identity.listForEstate(request.actor.userId, estateId);
  }

  @Post('verifications/:verificationId/decide')
  decide(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('verificationId', ParseUUIDPipe) verificationId: string, @Body() body: DecideIdentityVerificationDto) {
    return this.identity.decide(request.actor.userId, estateId, verificationId, body);
  }
}
