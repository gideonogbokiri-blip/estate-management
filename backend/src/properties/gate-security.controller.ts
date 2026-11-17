import { Body, Controller, Delete, Get, Headers, Param, ParseUUIDPipe, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { AccessEventsQueryDto, AssignGateStaffDto, CreateEstateGateDto, CreateSecurityContactDto, EstateGateContextDto, GateCheckInDto, ManualAdmissionDto } from './gate-security.dto.js';
import { GateSecurityService } from './gate-security.service.js';

@Controller('estate')
@UseGuards(AccessTokenGuard)
export class GateSecurityController {
  constructor(private readonly gates: GateSecurityService) {}

  @Get('security/gates')
  myGates(@Req() req: AuthenticatedRequest, @Query() query: EstateGateContextDto) {
    return this.gates.listMyGates(req.actor.userId, query.estateId);
  }

  @Get('estates/:estateId/security/officers')
  officers(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.gates.listSecurityOfficers(req.actor.userId, estateId);
  }

  @Get('estates/:estateId/security/gates')
  estateGates(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.gates.listEstateGates(req.actor.userId, estateId);
  }

  @Post('estates/:estateId/security/gates')
  create(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateEstateGateDto) {
    return this.gates.createGate(req.actor.userId, estateId, body);
  }

  @Post('estates/:estateId/security/gates/:gateId/assignments')
  assign(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('gateId', ParseUUIDPipe) gateId: string, @Body() body: AssignGateStaffDto) {
    return this.gates.assignStaff(req.actor.userId, estateId, gateId, body.userId);
  }

  @Post('security/gates/:gateId/check-in')
  checkIn(@Req() req: AuthenticatedRequest, @Param('gateId', ParseUUIDPipe) gateId: string,
    @Query() query: EstateGateContextDto, @Headers('idempotency-key') key: string | undefined, @Body() body: GateCheckInDto) {
    return this.gates.checkIn(req.actor.userId, query.estateId, gateId, body.credential, key, {
      remoteAddress: req.ip ?? req.socket.remoteAddress ?? 'unknown', userAgent: req.get('user-agent') ?? '',
    });
  }

  @Get('security/gates/:gateId/visitors/current')
  current(@Req() req: AuthenticatedRequest, @Param('gateId', ParseUUIDPipe) gateId: string, @Query() query: EstateGateContextDto) {
    return this.gates.listCurrent(req.actor.userId, query.estateId, gateId);
  }

  @Get('security/gates/:gateId/visitors/expected')
  expected(@Req() req: AuthenticatedRequest, @Param('gateId', ParseUUIDPipe) gateId: string, @Query() query: EstateGateContextDto) {
    return this.gates.listExpected(req.actor.userId, query.estateId, gateId);
  }

  @Post('security/gates/:gateId/manual-admissions')
  manualAdmission(@Req() req: AuthenticatedRequest, @Param('gateId', ParseUUIDPipe) gateId: string,
    @Query() query: EstateGateContextDto, @Headers('idempotency-key') key: string | undefined, @Body() body: ManualAdmissionDto) {
    return this.gates.manualAdmission(req.actor.userId, query.estateId, gateId, body, key);
  }

  @Get('estates/:estateId/security/access-events')
  accessEvents(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Query() query: AccessEventsQueryDto) {
    return this.gates.listAccessEvents(req.actor.userId, estateId, query);
  }

  @Get('estates/:estateId/security/contacts')
  securityContacts(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.gates.listSecurityContacts(req.actor.userId, estateId);
  }

  @Post('estates/:estateId/security/contacts')
  createSecurityContact(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateSecurityContactDto) {
    return this.gates.createSecurityContact(req.actor.userId, estateId, body);
  }

  @Delete('estates/:estateId/security/contacts/:contactId')
  removeSecurityContact(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('contactId', ParseUUIDPipe) contactId: string) {
    return this.gates.removeSecurityContact(req.actor.userId, estateId, contactId);
  }

  @Post('security/gates/:gateId/visits/:visitId/check-out')
  checkOut(@Req() req: AuthenticatedRequest, @Param('gateId', ParseUUIDPipe) gateId: string,
    @Param('visitId', ParseUUIDPipe) visitId: string, @Query() query: EstateGateContextDto) {
    return this.gates.checkOut(req.actor.userId, query.estateId, gateId, visitId);
  }
}
