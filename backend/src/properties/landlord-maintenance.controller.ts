import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { LandlordMaintenanceQueryDto } from './maintenance.dto.js';
import { MaintenanceService } from './maintenance.service.js';

@Controller('landlord/properties')
@UseGuards(AccessTokenGuard)
export class LandlordMaintenanceController {
  constructor(private readonly maintenance: MaintenanceService) {}

  @Get('maintenance')
  list(@Req() request: AuthenticatedRequest, @Query() query: LandlordMaintenanceQueryDto) {
    return this.maintenance.listMyLandlordPropertyMaintenance(
      request.actor.userId,
      query.page,
      query.pageSize,
    );
  }
}
