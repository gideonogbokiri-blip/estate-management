import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { TenantAccessService } from './tenant-access.service.js';

@Controller('estate/tenancies/mine')
@UseGuards(AccessTokenGuard)
export class TenantAccessController {
  constructor(private readonly tenancy: TenantAccessService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest) {
    return this.tenancy.listMine(request.actor.userId);
  }
}
