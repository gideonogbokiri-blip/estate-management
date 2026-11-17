import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateEstateChargeDto, CreateEstateChargeVersionDto, CreateEstateInvoiceDraftDto, CreateEstateSettlementPolicyDto, RecordEstateInvoiceSettlementDto } from './charges.dto.js';
import { EstateChargesService } from './charges.service.js';

@Controller('estate/estates/:estateId/charges')
@UseGuards(AccessTokenGuard)
export class EstateChargesController {
  constructor(private readonly charges: EstateChargesService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.charges.list(request.actor.userId, estateId);
  }

  @Get('invoice-drafts')
  listInvoiceDrafts(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.charges.listInvoiceDrafts(request.actor.userId, estateId);
  }

  @Get('settlement-policies')
  listSettlementPolicies(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.charges.listSettlementPolicies(request.actor.userId, estateId);
  }

  @Post('settlement-policies')
  createSettlementPolicy(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateEstateSettlementPolicyDto) {
    return this.charges.createSettlementPolicy(request.actor.userId, estateId, body);
  }

  @Post('settlement-policies/:policyId/activate')
  activateSettlementPolicy(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('policyId', ParseUUIDPipe) policyId: string) {
    return this.charges.activateSettlementPolicy(request.actor.userId, estateId, policyId);
  }

  @Post('invoice-drafts')
  createInvoiceDraft(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined, @Body() body: CreateEstateInvoiceDraftDto) {
    return this.charges.createInvoiceDraft(request.actor.userId, estateId, body, idempotencyKey);
  }

  @Post('invoice-drafts/:invoiceDraftId/issue')
  issueInvoiceDraft(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('invoiceDraftId', ParseUUIDPipe) invoiceDraftId: string) {
    return this.charges.issueInvoiceDraft(request.actor.userId, estateId, invoiceDraftId);
  }

  @Post('invoices/:invoiceId/settlements')
  recordInvoiceSettlement(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('invoiceId', ParseUUIDPipe) invoiceId: string, @Body() body: RecordEstateInvoiceSettlementDto) {
    return this.charges.recordInvoiceSettlement(request.actor.userId, estateId, invoiceId, body);
  }

  @Post()
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateEstateChargeDto) {
    return this.charges.create(request.actor.userId, estateId, body);
  }

  @Post(':chargeId/versions')
  createVersion(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('chargeId', ParseUUIDPipe) chargeId: string, @Body() body: CreateEstateChargeVersionDto) {
    return this.charges.createVersion(request.actor.userId, estateId, chargeId, body);
  }

  @Post(':chargeId/versions/:versionId/activate')
  activateVersion(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('chargeId', ParseUUIDPipe) chargeId: string, @Param('versionId', ParseUUIDPipe) versionId: string) {
    return this.charges.activateVersion(request.actor.userId, estateId, chargeId, versionId);
  }
}

@Controller('estate/invoices/mine')
@UseGuards(AccessTokenGuard)
export class ResidentInvoicesController {
  constructor(private readonly charges: EstateChargesService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest) {
    return this.charges.listMyInvoices(request.actor.userId);
  }
}
