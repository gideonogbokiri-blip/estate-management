import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { EstateSettingsService } from './estate-settings.service.js';
import { UpdateEstateSettingsDto } from './estate-settings.dto.js';

@Controller('estate/estates/:estateId/settings')
@UseGuards(AccessTokenGuard)
export class EstateSettingsController {
  constructor(private readonly settings: EstateSettingsService) {}

  @Get()
  read(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.settings.read(request.actor.userId, estateId);
  }

  @Patch()
  update(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: UpdateEstateSettingsDto) {
    return this.settings.update(request.actor.userId, estateId, body);
  }
}
