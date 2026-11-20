import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateBeneficiaryDto, CreatePayoutDto, DecidePayoutDto, UpdatePayoutPolicyDto } from './payouts.dto.js';
import { EstatePayoutService } from './payouts.service.js';

@Controller('estate/estates/:estateId/finance')
@UseGuards(AccessTokenGuard)
export class EstatePayoutController {
  constructor(private readonly payouts: EstatePayoutService) {}

  @Get('payout-policy')
  policy(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.payouts.policy(req.actor.userId, estateId);
  }

  @Patch('payout-policy')
  updatePolicy(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Body() body: UpdatePayoutPolicyDto) {
    return this.payouts.updatePolicy(req.actor.userId, estateId, body.threshold, body.requiredApprovals);
  }

  @Get('beneficiaries')
  async beneficiaries(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return { items: await this.payouts.listBeneficiaries(req.actor.userId, estateId) };
  }

  @Post('beneficiaries')
  createBeneficiary(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Body() body: CreateBeneficiaryDto) {
    return this.payouts.createBeneficiary(req.actor.userId, estateId, body);
  }

  @Post('beneficiaries/:beneficiaryId/verify')
  verifyBeneficiary(@Req() req: AuthenticatedRequest,
    @Param('beneficiaryId', ParseUUIDPipe) beneficiaryId: string) {
    return this.payouts.verifyBeneficiary(req.actor.userId, beneficiaryId);
  }

  @Get('payouts')
  async list(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return { items: await this.payouts.list(req.actor.userId, estateId) };
  }

  @Post('payouts')
  create(@Req() req: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Headers('idempotency-key') key: string | undefined, @Body() body: CreatePayoutDto) {
    return this.payouts.create(req.actor.userId, estateId, body, key, JSON.stringify(body));
  }

  @Post('payouts/:payoutId/decision')
  decide(@Req() req: AuthenticatedRequest, @Param('payoutId', ParseUUIDPipe) payoutId: string,
    @Body() body: DecidePayoutDto) {
    return this.payouts.approve(req.actor.userId, payoutId, body.decision, body.note ?? '');
  }

  @Post('payouts/:payoutId/execute')
  execute(@Req() req: AuthenticatedRequest, @Param('payoutId', ParseUUIDPipe) payoutId: string,
    @Headers('idempotency-key') key: string | undefined) {
    return this.payouts.execute(req.actor.userId, payoutId, key);
  }
}
