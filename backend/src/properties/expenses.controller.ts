import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Post, Put, Req, UseGuards } from '@nestjs/common';
import { AccessTokenGuard } from '../auth/access-token.guard.js';
import type { AuthenticatedRequest } from '../auth/access-token.guard.js';
import { ConfigureExpensePolicyDto, CreateExpenseCategoryDto, CreateExpensePayeeDto, CreateExpenseRequestDto, ReconcileEstateExpenseDto, SubmitExpenseDecisionDto } from './expenses.dto.js';
import { EstateExpensesService } from './expenses.service.js';

@Controller('estate/estates/:estateId/expenses')
@UseGuards(AccessTokenGuard)
export class EstateExpensesController {
  constructor(private readonly expenses: EstateExpensesService) {}

  @Get()
  list(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.expenses.list(request.actor.userId, estateId);
  }

  @Get('policy')
  policy(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.expenses.readPolicy(request.actor.userId, estateId);
  }

  @Put('policy')
  configurePolicy(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: ConfigureExpensePolicyDto) {
    return this.expenses.configurePolicy(request.actor.userId, estateId, body);
  }

  @Get('categories')
  categories(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.expenses.categories(request.actor.userId, estateId);
  }

  @Post('categories')
  createCategory(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateExpenseCategoryDto) {
    return this.expenses.createCategory(request.actor.userId, estateId, body);
  }

  @Get('payees')
  payees(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string) {
    return this.expenses.payees(request.actor.userId, estateId);
  }

  @Post('payees')
  createPayee(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Body() body: CreateExpensePayeeDto) {
    return this.expenses.createPayee(request.actor.userId, estateId, body);
  }

  @Post('payees/:payeeId/verify')
  verifyPayee(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('payeeId', ParseUUIDPipe) payeeId: string) {
    return this.expenses.verifyPayee(request.actor.userId, estateId, payeeId);
  }

  @Post()
  create(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Headers('idempotency-key') idempotencyKey: string | undefined, @Body() body: CreateExpenseRequestDto) {
    return this.expenses.createDraft(request.actor.userId, estateId, body, idempotencyKey);
  }

  @Post(':expenseId/submit')
  submit(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string, @Param('expenseId', ParseUUIDPipe) expenseId: string) {
    return this.expenses.submit(request.actor.userId, estateId, expenseId);
  }

  @Post(':expenseId/decision')
  decide(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('expenseId', ParseUUIDPipe) expenseId: string, @Body() body: SubmitExpenseDecisionDto) {
    return this.expenses.decide(request.actor.userId, estateId, expenseId, body);
  }

  @Post(':expenseId/settlements')
  reconcile(@Req() request: AuthenticatedRequest, @Param('estateId', ParseUUIDPipe) estateId: string,
    @Param('expenseId', ParseUUIDPipe) expenseId: string, @Headers('idempotency-key') idempotencyKey: string | undefined,
    @Body() body: ReconcileEstateExpenseDto) {
    return this.expenses.reconcile(request.actor.userId, estateId, expenseId, body, idempotencyKey);
  }
}
