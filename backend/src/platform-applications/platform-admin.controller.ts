import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { PlatformEstateQueryDto, PlatformTeamRoleDto } from './platform-admin.dto.js';
import { PlatformAdminService } from './platform-admin.service.js';

@Controller('platform/admin')
@UseGuards(AccessTokenGuard)
export class PlatformAdminController {
  constructor(private readonly admin: PlatformAdminService) {}

  @Get('team')
  team(@Req() req: AuthenticatedRequest) {
    return this.admin.team(req.actor.userId);
  }

  @Get('team/candidates')
  candidates(@Req() req: AuthenticatedRequest, @Query('search') search?: string) {
    return this.admin.candidateUsers(req.actor.userId, search ?? '');
  }

  @Post('team/roles')
  grant(@Req() req: AuthenticatedRequest, @Body() body: PlatformTeamRoleDto) {
    return this.admin.grantRole(req.actor.userId, body.userId, body.roleKey);
  }

  @Delete('team/roles/:userId/:roleKey')
  revoke(@Req() req: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('roleKey') roleKey: string) {
    return this.admin.revokeRole(req.actor.userId, userId, roleKey);
  }

  @Get('estates')
  estates(@Req() req: AuthenticatedRequest, @Query() query: PlatformEstateQueryDto) {
    return this.admin.estates(req.actor.userId, query);
  }
}
