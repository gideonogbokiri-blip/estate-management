import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateEstateServiceDto, SetEstateServiceStatusDto } from './services.dto.js';
import { EstateServicesService } from './services.service.js';

@Controller('estate/estates/:estateId/services')
@UseGuards(AccessTokenGuard)
export class EstateServicesController {
  constructor(private readonly services: EstateServicesService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.services.listDefinitions(request.actor.userId, estateId);
  }

  @Post()
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Body() body: CreateEstateServiceDto) {
    return this.services.createDefinition(request.actor.userId, estateId, body);
  }

  @Get('orders')
  orders(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.services.listOrders(request.actor.userId, estateId);
  }

  @Post(':serviceId/orders')
  order(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined) {
    return this.services.order(request.actor.userId, estateId, serviceId, idempotencyKey);
  }

  @Patch(':serviceId/status')
  setStatus(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('serviceId', ParseUUIDPipe) serviceId: string, @Body() body: SetEstateServiceStatusDto) {
    return this.services.setStatus(request.actor.userId, estateId, serviceId, body);
  }
}
