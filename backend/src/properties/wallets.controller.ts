import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { PayWalletRentDto, ProvisionWalletDto } from './wallets.dto.js';
import { EstateWalletService } from './wallets.service.js';

@Controller('estate/wallets')
@UseGuards(AccessTokenGuard)
export class EstateWalletsController {
  constructor(private readonly wallets: EstateWalletService) {}

  @Get('mine')
  mine(@Req() request: AuthenticatedRequest) {
    return this.wallets.mine(request.actor.userId);
  }

  @Post('provision')
  provision(@Req() request: AuthenticatedRequest, @Body() body: ProvisionWalletDto) {
    return this.wallets.provision(request.actor.userId, body.estateId);
  }

  @Post('pay-rent')
  payRent(@Req() request: AuthenticatedRequest, @Body() body: PayWalletRentDto) {
    return this.wallets.payRent(request.actor.userId, body.estateId, body.invoiceId, body.amount);
  }
}

@Controller('payments/paystack')
export class PaystackWebhookController {
  constructor(private readonly wallets: EstateWalletService) {}

  @Post('webhook')
  webhook(@Req() request: Request) {
    const signature = request.headers['x-paystack-signature'];
    const body = Buffer.isBuffer(request.body) ? request.body : Buffer.from(JSON.stringify(request.body ?? {}));
    return this.wallets.handleWebhook(body, typeof signature === 'string' ? signature : undefined);
  }
}
