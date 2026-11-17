import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { CreateEstateBudgetDto, DecideEstateBudgetDto } from './expenses.dto.js';
import { EstateBudgetsService } from './budgets.service.js';

@Controller('estate/estates/:estateId/budgets')
@UseGuards(AccessTokenGuard)
export class EstateBudgetsController {
  constructor(private readonly budgets: EstateBudgetsService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.budgets.list(request.actor.userId, estateId);
  }

  @Post()
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateEstateBudgetDto) {
    return this.budgets.create(request.actor.userId, estateId, body);
  }

  @Post(':budgetId/submit')
  submit(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('budgetId', ParseUUIDPipe) budgetId: string) {
    return this.budgets.submit(request.actor.userId, estateId, budgetId);
  }

  @Post(':budgetId/decision')
  decide(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('budgetId', ParseUUIDPipe) budgetId: string, @Body() body: DecideEstateBudgetDto) {
    return this.budgets.decide(request.actor.userId, estateId, budgetId, body);
  }
}
