import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { PropertiesService } from './properties.service.js';
import { StructureNodeDraftDto, StructureQueryDto, UpdateStructureNodeDto } from './structure.dto.js';

@Controller('estate/estates/:estateId/structure')
@UseGuards(AccessTokenGuard)
export class StructureController {
  constructor(private readonly properties: PropertiesService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Query() query: StructureQueryDto) {
    return this.properties.listStructure(request.actor.userId, estateId, query.includeArchived);
  }

  @Post('nodes')
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: StructureNodeDraftDto) {
    return this.properties.createStructureNode(request.actor.userId, estateId, body);
  }

  @Patch('nodes/:nodeId')
  update(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('nodeId', ParseUUIDPipe) nodeId: string, @Body() body: UpdateStructureNodeDto) {
    return this.properties.updateStructureNode(request.actor.userId, estateId, nodeId, body);
  }

  @Delete('nodes/:nodeId')
  archive(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('nodeId', ParseUUIDPipe) nodeId: string) {
    return this.properties.archiveStructureNode(request.actor.userId, estateId, nodeId);
  }
}
