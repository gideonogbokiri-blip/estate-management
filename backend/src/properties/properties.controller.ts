import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import {
  PropertyDraftDto,
  PropertyQueryDto,
  UpdatePropertyDto,
} from './properties.dto.js';
import { PropertiesService } from './properties.service.js';

@Controller('estate/estates/:estateId/properties')
@UseGuards(AccessTokenGuard)
export class PropertiesController {
  constructor(private readonly properties: PropertiesService) {}

  @Get()
  list(
    @Req() request: AuthenticatedRequest,
    @Param('estateId', new ParseUUIDPipe()) estateId: string,
    @Query() query: PropertyQueryDto,
  ) {
    return this.properties.list(request.actor.userId, estateId, query);
  }

  @Post()
  create(
    @Req() request: AuthenticatedRequest,
    @Param('estateId', new ParseUUIDPipe()) estateId: string,
    @Body() body: PropertyDraftDto,
  ) {
    return this.properties.create(request.actor.userId, estateId, body);
  }

  @Patch(':propertyId')
  update(
    @Req() request: AuthenticatedRequest,
    @Param('estateId', new ParseUUIDPipe()) estateId: string,
    @Param('propertyId', new ParseUUIDPipe()) propertyId: string,
    @Body() body: UpdatePropertyDto,
  ) {
    return this.properties.update(request.actor.userId, estateId, propertyId, body);
  }

  @Post(':propertyId/archive')
  archive(
    @Req() request: AuthenticatedRequest,
    @Param('estateId', new ParseUUIDPipe()) estateId: string,
    @Param('propertyId', new ParseUUIDPipe()) propertyId: string,
  ) {
    return this.properties.archiveProperty(request.actor.userId, estateId, propertyId);
  }
}
