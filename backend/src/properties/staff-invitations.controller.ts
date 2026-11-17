import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { AcceptStaffInvitationDto, CreateStaffInvitationDto } from './staff-invitations.dto.js';
import { StaffInvitationsService } from './staff-invitations.service.js';

@Controller('estate')
@UseGuards(AccessTokenGuard)
export class StaffInvitationsController {
  constructor(private readonly invitations: StaffInvitationsService) {}

  @Get('estates/:estateId/staff-invitations')
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.invitations.list(request.actor.userId, estateId);
  }

  @Post('estates/:estateId/staff-invitations')
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateStaffInvitationDto) {
    return this.invitations.create(request.actor.userId, estateId, body);
  }

  @Delete('estates/:estateId/staff-invitations/:invitationId')
  revoke(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('invitationId', ParseUUIDPipe) invitationId: string) {
    return this.invitations.revoke(request.actor.userId, estateId, invitationId);
  }

  @Post('estates/:estateId/staff-invitations/accept')
  accept(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: AcceptStaffInvitationDto) {
    return this.invitations.accept(request.actor.userId, estateId, body.token);
  }
}
