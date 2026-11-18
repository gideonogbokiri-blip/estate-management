import { Body, Controller, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from './access-token.guard.js';
import type { AuthenticatedRequest } from './access-token.guard.js';
import { AccountLifecycleService } from './account-lifecycle.service.js';
import { ConfirmRecoveryDto, IssueRecoveryCodeDto } from './account-lifecycle.dto.js';

@Controller('auth')
export class AccountLifecycleController {
  constructor(private readonly lifecycle: AccountLifecycleService) {}

  @Post('confirm-recovery')
  confirm(@Body() body: ConfirmRecoveryDto) {
    return this.lifecycle.confirm(body.email, body.code, body.newPassword);
  }

  @Post('accounts/:userId/recovery-codes')
  @UseGuards(AccessTokenGuard)
  issue(@Req() req: AuthenticatedRequest, @Param('userId', ParseUUIDPipe) userId: string,
    @Body() body: IssueRecoveryCodeDto) {
    return this.lifecycle.issue(userId, body.purpose, req.actor.userId);
  }
}
