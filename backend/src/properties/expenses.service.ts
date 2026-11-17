import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { EstateNotificationsService } from './notifications.service.js';
import type { ConfigureExpensePolicyDto, CreateExpenseCategoryDto, CreateExpensePayeeDto, CreateExpenseRequestDto, ReconcileEstateExpenseDto, SubmitExpenseDecisionDto } from './expenses.dto.js';

const FINANCE_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER', 'FINANCE_MANAGER'] as const;
const POLICY_ROLES = ['ESTATE_ADMINISTRATOR', 'FINANCE_MANAGER'] as const;

@Injectable()
export class EstateExpensesService {
  constructor(private readonly prisma: PrismaService, private readonly notifications: EstateNotificationsService) {}

  async list(actorId: string, estateId: string) {
    await this.requireRole(this.prisma, actorId, estateId, FINANCE_ROLES);
    const memberships = await this.prisma.estateMembership.findMany({ where: { userId: actorId, estateId, status: 'ACTIVE' }, select: { role: true } });
    const policy = await this.prisma.estateExpensePolicy.findUnique({ where: { estateId } });
    const rows = await this.prisma.estateExpenseRequest.findMany({
      where: { estateId }, orderBy: [{ submittedAt: 'desc' }, { createdAt: 'desc' }], take: 200,
      include: {
        category: { select: { name: true, code: true } },
        budgetLine: { include: { category: { select: { name: true, code: true } }, budget: { select: { currency: true, periodStart: true, periodEnd: true, status: true } } } },
        payee: { select: { displayName: true, reference: true, currency: true, verifiedAt: true } },
        requester: { select: { displayName: true } },
        decisions: { orderBy: { occurredAt: 'asc' }, include: { actor: { select: { displayName: true } } } },
        settlements: { orderBy: { receivedAt: 'desc' }, take: 10 },
      },
    });
    const roles = memberships.map((membership) => membership.role);
    const paymentTotals = rows.length ? await this.prisma.estateExpenseSettlement.groupBy({
      by: ['expenseId'], where: { estateId, expenseId: { in: rows.map((row) => row.id) } }, _sum: { amount: true },
    }) : [];
    const paidByExpense = new Map(paymentTotals.map((row) => [row.expenseId, row._sum.amount ?? new Prisma.Decimal(0)]));
    return { estateId, items: rows.map((row) => ({ ...this.view(row, paidByExpense.get(row.id) ?? new Prisma.Decimal(0)), allowedCommands: this.allowedCommands(row, actorId, roles, policy) })) };
  }

  async readPolicy(actorId: string, estateId: string) {
    await this.requireRole(this.prisma, actorId, estateId, FINANCE_ROLES);
    const policy = await this.prisma.estateExpensePolicy.findUnique({ where: { estateId } });
    if (!policy) return { estateId, configured: false, policy: null };
    return { estateId, configured: true, policy: this.policyView(policy) };
  }

  async configurePolicy(actorId: string, estateId: string, input: ConfigureExpensePolicyDto) {
    await this.requireRole(this.prisma, actorId, estateId, POLICY_ROLES);
    const stages = input.stages.map((stage) => {
      if (!POLICY_ROLES.includes(stage.role as (typeof POLICY_ROLES)[number])) throw new BadRequestException('Approval stages may use only estate administrators or finance managers.');
      if (stage.maximumAmount && (!this.validMoney(stage.maximumAmount) || new Prisma.Decimal(stage.maximumAmount).lte(0))) throw new BadRequestException('Approval limits must be positive amounts with no more than two decimal places.');
      return { role: stage.role, maximumAmount: stage.maximumAmount ?? null };
    });
    if (new Set(stages.map((stage) => stage.role)).size !== stages.length && input.requireDistinctApprovers) {
      throw new BadRequestException('A distinct-approver policy cannot repeat the same role in consecutive stages.');
    }
    const saved = await this.prisma.$transaction(async (tx) => {
      const previous = await tx.estateExpensePolicy.findUnique({ where: { estateId } });
      const version = (previous?.version ?? 0) + 1;
      const policy = await tx.estateExpensePolicy.upsert({
        where: { estateId },
        create: { estateId, version, approvalStages: stages, allowUnbudgeted: input.allowUnbudgeted,
          preventRequesterApproval: true, requireDistinctApprovers: input.requireDistinctApprovers, updatedById: actorId },
        update: { version, approvalStages: stages, allowUnbudgeted: input.allowUnbudgeted,
          preventRequesterApproval: true, requireDistinctApprovers: input.requireDistinctApprovers, updatedById: actorId },
      });
      await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'expense.policy_configured',
        targetType: 'expense_policy', targetId: policy.id, outcome: 'success', occurredAt: new Date(), metadata: { version, stages } } });
      return policy;
    });
    return { estateId, configured: true, policy: this.policyView(saved) };
  }

  async categories(actorId: string, estateId: string) {
    await this.requireRole(this.prisma, actorId, estateId, FINANCE_ROLES);
    const items = await this.prisma.estateExpenseCategory.findMany({ where: { estateId }, orderBy: [{ active: 'desc' }, { name: 'asc' }], take: 200 });
    return { estateId, items };
  }

  async createCategory(actorId: string, estateId: string, input: CreateExpenseCategoryDto) {
    await this.requireRole(this.prisma, actorId, estateId, POLICY_ROLES);
    try {
      const row = await this.prisma.estateExpenseCategory.create({ data: {
        estateId, code: input.code.trim().toUpperCase(), name: input.name.trim(), createdById: actorId,
      } });
      await this.audit(actorId, estateId, 'expense.category_created', 'expense_category', row.id);
      return row;
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('That expense category code already exists in this estate.');
      throw error;
    }
  }

  async payees(actorId: string, estateId: string) {
    await this.requireRole(this.prisma, actorId, estateId, FINANCE_ROLES);
    const items = await this.prisma.estateExpensePayee.findMany({ where: { estateId }, orderBy: { displayName: 'asc' }, take: 200 });
    return { estateId, items: items.map((row) => ({ ...row, verified: row.verifiedAt !== null })) };
  }

  async createPayee(actorId: string, estateId: string, input: CreateExpensePayeeDto) {
    await this.requireRole(this.prisma, actorId, estateId, POLICY_ROLES);
    const destinationReference = input.destinationReference.trim();
    if (!input.displayName.trim() || !/^ref:[A-Za-z0-9._-]{4,112}$/.test(destinationReference)) throw new BadRequestException('Use an opaque `ref:` identifier for the payee destination; bank and account numbers must not be entered here.');
    try {
      const row = await this.prisma.estateExpensePayee.create({ data: {
        estateId, reference: input.reference.trim().toUpperCase(), displayName: input.displayName.trim(),
        currency: input.currency, destinationReference, createdById: actorId,
      } });
      await this.audit(actorId, estateId, 'expense.payee_created', 'expense_payee', row.id);
      return { ...row, verified: false };
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('That payee reference already exists in this estate.');
      throw error;
    }
  }

  async verifyPayee(actorId: string, estateId: string, payeeId: string) {
    await this.requireRole(this.prisma, actorId, estateId, POLICY_ROLES);
    const row = await this.prisma.estateExpensePayee.findFirst({ where: { id: payeeId, estateId } });
    if (!row) throw new NotFoundException('Payee not found in this estate.');
    if (row.verifiedAt) return { ...row, verified: true };
    const verifiedAt = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
      const payee = await tx.estateExpensePayee.update({ where: { id: row.id }, data: { verifiedAt, verifiedById: actorId } });
      await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'expense.payee_verified',
        targetType: 'expense_payee', targetId: row.id, outcome: 'success', occurredAt: verifiedAt } });
      return payee;
    });
    return { ...updated, verified: true };
  }

  async createDraft(actorId: string, estateId: string, input: CreateExpenseRequestDto, idempotencyKey: string | undefined) {
    await this.requireRole(this.prisma, actorId, estateId, FINANCE_ROLES);
    if (!idempotencyKey || idempotencyKey.length < 8 || idempotencyKey.length > 128) throw new BadRequestException('A valid Idempotency-Key header is required.');
    const description = input.description.trim();
    if (!description || !this.validMoney(input.amount) || new Prisma.Decimal(input.amount).lte(0)) throw new BadRequestException('Provide a description and a positive amount with no more than two decimal places.');
    if (input.neededBy && !this.validDate(input.neededBy)) throw new BadRequestException('Provide a real needed-by date in YYYY-MM-DD format.');
    const category = await this.prisma.estateExpenseCategory.findFirst({ where: { id: input.categoryId, estateId, active: true }, select: { id: true } });
    if (!category) throw new BadRequestException('Select an active expense category in this estate.');
    const payee = await this.prisma.estateExpensePayee.findFirst({ where: { id: input.payeeId, estateId }, select: { id: true, currency: true } });
    if (!payee || payee.currency !== input.currency) throw new BadRequestException('Select a same-estate payee in the expense currency.');
    if (input.budgetLineId) {
      const line = await this.prisma.estateBudgetLine.findFirst({ where: { id: input.budgetLineId, estateId, categoryId: category.id, budget: { estateId, status: 'APPROVED', currency: input.currency } }, include: { budget: { select: { periodStart: true, periodEnd: true } } } });
      const effectiveDate = input.neededBy ? new Date(`${input.neededBy}T00:00:00.000Z`) : new Date();
      if (!line || effectiveDate < line.budget.periodStart || effectiveDate > line.budget.periodEnd) throw new BadRequestException('Select an approved same-estate budget line for this category, currency and needed-by date.');
    }
    const idempotencyKeyHash = this.hash(`estate-expense:v1:${idempotencyKey}`);
    const payloadHash = this.hash(JSON.stringify({ ...input, description }));
    const unique = { estateId_requesterUserId_idempotencyKeyHash: { estateId, requesterUserId: actorId, idempotencyKeyHash } };
    const prior = await this.prisma.estateExpenseRequest.findUnique({ where: unique });
    if (prior) {
      if (prior.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was already used for a different expense request.');
      return { ...prior, replayed: true };
    }
    const id = randomUUID();
    try {
      const row = await this.prisma.estateExpenseRequest.create({ data: {
        id, estateId, code: `EXP-${id.replaceAll('-', '').slice(0, 10).toUpperCase()}`,
        requesterUserId: actorId, categoryId: category.id, payeeId: payee.id, budgetLineId: input.budgetLineId ?? null, description,
        amount: new Prisma.Decimal(input.amount), currency: input.currency,
        neededBy: input.neededBy ? new Date(`${input.neededBy}T00:00:00.000Z`) : null,
        idempotencyKeyHash, payloadHash,
      } });
      await this.audit(actorId, estateId, 'expense.draft_created', 'expense_request', row.id);
      return { ...row, amount: row.amount.toString(), status: row.status.toLowerCase(), replayed: false };
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') {
        const existing = await this.prisma.estateExpenseRequest.findUnique({ where: unique });
        if (existing?.payloadHash === payloadHash) return { ...existing, replayed: true };
      }
      throw error;
    }
  }

  async submit(actorId: string, estateId: string, expenseId: string) {
    return this.prisma.$transaction(async (tx) => {
      await this.requireRole(tx, actorId, estateId, FINANCE_ROLES);
      await tx.$queryRaw`SELECT id FROM estate_expense_requests WHERE id = ${expenseId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
      const expense = await tx.estateExpenseRequest.findFirst({ where: { id: expenseId, estateId, requesterUserId: actorId }, include: { payee: true, category: true, budgetLine: { include: { budget: true } } } });
      if (!expense) throw new NotFoundException('Draft expense not found in this estate.');
      if (expense.status !== 'DRAFT') throw new ConflictException('Only a draft expense can be submitted.');
      const policy = await tx.estateExpensePolicy.findUnique({ where: { estateId } });
      if (!policy) throw new ConflictException('Configure an expense approval policy before submitting requests.');
      if (!policy.allowUnbudgeted && !this.budgetLineValid(expense.budgetLine, expense.categoryId, expense.currency, expense.neededBy ?? new Date())) throw new ConflictException('Select a current approved budget line before submitting this request.');
      if (!expense.payee.verifiedAt || expense.payee.currency !== expense.currency || !expense.payee.destinationReference) throw new ConflictException('Verify the same-estate payee destination before submitting.');
      const stages = policy.approvalStages as Array<{ role: string; maximumAmount: string | null }>;
      if (!Array.isArray(stages) || !stages.length) throw new ConflictException('The expense approval policy has no valid approval stage.');
      const submittedAt = new Date();
      const updated = await tx.estateExpenseRequest.update({ where: { id: expense.id }, data: {
        status: 'PENDING_APPROVAL', approvalPolicyVersion: policy.version, approvalStageIndex: 0, submittedAt,
      } });
      await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'expense.submitted', targetType: 'expense_request', targetId: expense.id, outcome: 'success', occurredAt: submittedAt, metadata: { policyVersion: policy.version } } });
      const firstStage = stages[0];
      await this.notifications.enqueueRoles(tx, { estateId, roles: [firstStage.role], excludeUserId: actorId,
        eventKey: `expense:${expense.id}:submitted:${policy.version}:0`, type: 'EXPENSE', title: 'Expense request awaiting review',
        message: `${expense.code} is awaiting approval (${expense.currency} ${expense.amount.toFixed(2)}).`, sourceId: expense.id });
      return this.view({ ...updated, category: expense.category, payee: expense.payee, budgetLine: expense.budgetLine ? { id: expense.budgetLine.id, category: expense.category } : null, requester: { displayName: '' }, decisions: [] });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async decide(actorId: string, estateId: string, expenseId: string, input: SubmitExpenseDecisionDto) {
    const reason = input.reason?.trim() ?? '';
    if (input.decision === 'reject' && !reason) throw new BadRequestException('A reason is required to reject an expense.');
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM estate_expense_requests WHERE id = ${expenseId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
      const expense = await tx.estateExpenseRequest.findFirst({ where: { id: expenseId, estateId }, include: {
        category: { select: { name: true, code: true } }, payee: true, budgetLine: { include: { category: { select: { name: true, code: true } }, budget: { select: { currency: true, periodStart: true, periodEnd: true, status: true } } } }, requester: { select: { displayName: true } },
        decisions: { orderBy: { occurredAt: 'asc' }, include: { actor: { select: { displayName: true } } } },
      } });
      if (!expense) throw new NotFoundException('Expense request not found in this estate.');
      if (expense.status !== 'PENDING_APPROVAL' || expense.approvalPolicyVersion === null) throw new ConflictException('Only a pending expense can receive a decision.');
      const policy = await tx.estateExpensePolicy.findUnique({ where: { estateId } });
      if (!policy || policy.version !== expense.approvalPolicyVersion) throw new ConflictException('The approval policy changed; review a newly submitted request.');
      const stages = policy.approvalStages as Array<{ role: string; maximumAmount: string | null }>;
      const stage = stages[expense.approvalStageIndex];
      if (!stage || !POLICY_ROLES.includes(stage.role as (typeof POLICY_ROLES)[number])) throw new ConflictException('The current approval stage is not configured.');
      const membership = await tx.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', role: stage.role as (typeof POLICY_ROLES)[number], estate: { status: 'ACTIVE' } }, select: { role: true } });
      if (!membership) throw new ForbiddenException('You do not have the role assigned to this approval stage.');
      if (input.decision === 'approve' && policy.preventRequesterApproval && expense.requesterUserId === actorId) throw new ForbiddenException('The requester cannot approve their own expense.');
      if (input.decision === 'approve' && policy.requireDistinctApprovers && expense.decisions.some((item) => item.actorUserId === actorId)) throw new ForbiddenException('A different approver is required for this stage.');
      if (input.decision === 'approve' && stage.maximumAmount && expense.amount.gt(new Prisma.Decimal(stage.maximumAmount))) throw new ForbiddenException('This approval stage cannot approve the requested amount.');
      const nextStageIndex = input.decision === 'approve' ? expense.approvalStageIndex + 1 : expense.approvalStageIndex;
      const finalApproval = input.decision === 'approve' && nextStageIndex >= stages.length;
      if (finalApproval && (!expense.payee.verifiedAt || expense.payee.currency !== expense.currency || !expense.payee.destinationReference)) throw new ConflictException('A verified same-estate payee destination is required for final approval.');
      if (finalApproval && !policy.allowUnbudgeted && !expense.budgetLineId) throw new ConflictException('An approved budget line is required by the current policy.');
      if (finalApproval && expense.budgetLineId) {
        await tx.$queryRaw`SELECT id FROM estate_budget_lines WHERE id = ${expense.budgetLineId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const line = await tx.estateBudgetLine.findFirst({ where: { id: expense.budgetLineId, estateId }, include: { budget: true } });
        if (!line || !this.budgetLineValid(line, expense.categoryId, expense.currency, expense.neededBy ?? new Date())) throw new ConflictException('The linked approved budget line is no longer valid for this request.');
        const committed = await tx.estateExpenseRequest.aggregate({ where: { estateId, budgetLineId: line.id, status: 'APPROVED' }, _sum: { amount: true } });
        if ((committed._sum.amount ?? new Prisma.Decimal(0)).plus(expense.amount).gt(line.allocatedAmount)) throw new ConflictException('This request exceeds the remaining approved category budget.');
      }
      const nextStatus = input.decision === 'reject' ? 'REJECTED' : finalApproval ? 'APPROVED' : 'PENDING_APPROVAL';
      const occurredAt = new Date();
      const updated = await tx.estateExpenseRequest.update({ where: { id: expense.id }, data: {
        status: nextStatus, approvalStageIndex: nextStageIndex,
        ...(finalApproval ? { approvedDestinationSnapshot: expense.payee.destinationReference } : {}),
        decisions: { create: { stageIndex: expense.approvalStageIndex, actorUserId: actorId,
          role: membership.role, decision: nextStatus, reason: reason || null, occurredAt } },
      }, include: { category: { select: { name: true, code: true } }, payee: true, budgetLine: { include: { category: { select: { name: true, code: true } } } },
        requester: { select: { displayName: true } }, decisions: { orderBy: { occurredAt: 'asc' }, include: { actor: { select: { displayName: true } } } } } });
      await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId,
        action: `expense.${input.decision}`, targetType: 'expense_request', targetId: expense.id,
        outcome: 'success', reason: reason || null, occurredAt, metadata: { stageIndex: expense.approvalStageIndex, status: nextStatus } } });
      if (nextStatus === 'PENDING_APPROVAL') {
        const nextStage = stages[nextStageIndex];
        if (nextStage) await this.notifications.enqueueRoles(tx, { estateId, roles: [nextStage.role], excludeUserId: expense.requesterUserId,
          eventKey: `expense:${expense.id}:stage:${nextStageIndex}:policy:${policy.version}`, type: 'EXPENSE', title: 'Expense request awaiting review',
          message: `${expense.code} requires the next approval stage.`, sourceId: expense.id });
      } else {
        await this.notifications.enqueueUser(tx, { estateId, recipientUserId: expense.requesterUserId,
          eventKey: `expense:${expense.id}:decision:${nextStatus.toLowerCase()}:${expense.approvalStageIndex}`, type: 'EXPENSE',
          title: nextStatus === 'APPROVED' ? 'Expense request approved' : 'Expense request rejected',
          message: nextStatus === 'APPROVED' ? `${expense.code} was approved to spend. Payment is recorded separately.` : `${expense.code} was rejected. Review the decision history for details.`, sourceId: expense.id });
      }
      return this.view(updated);
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async reconcile(actorId: string, estateId: string, expenseId: string, input: ReconcileEstateExpenseDto, idempotencyKey: string | undefined) {
    await this.requireRole(this.prisma, actorId, estateId, POLICY_ROLES);
    if (!idempotencyKey || idempotencyKey.length < 8 || idempotencyKey.length > 128) throw new BadRequestException('A valid Idempotency-Key header is required.');
    const amount = input.amount.trim();
    const bankReference = input.bankReference.trim();
    const normalizedBankReference = bankReference.toUpperCase();
    const verificationNote = input.verificationNote.trim();
    if (!this.validMoney(amount) || new Prisma.Decimal(amount).lte(0)) throw new BadRequestException('Provide a positive reconciled amount with no more than two decimal places.');
    if (!this.validDate(input.receivedAt)) throw new BadRequestException('Provide a real bank received date in YYYY-MM-DD format.');
    if (verificationNote.length < 8) throw new BadRequestException('Record a meaningful note about how the bank transaction was verified.');
    const idempotencyKeyHash = this.hash(`estate-expense-reconcile:v1:${idempotencyKey}`);
    const payloadHash = this.hash(JSON.stringify({ amount, normalizedBankReference, receivedAt: input.receivedAt, verificationNote }));
    try {
      return await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM estate_expense_requests WHERE id = ${expenseId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const expense = await tx.estateExpenseRequest.findFirst({ where: { id: expenseId, estateId }, include: { settlements: true } });
        if (!expense) throw new NotFoundException('Expense request not found in this estate.');
        const unique = { estateId_verifiedById_idempotencyKeyHash: { estateId, verifiedById: actorId, idempotencyKeyHash } };
        const previous = await tx.estateExpenseSettlement.findUnique({ where: unique });
        if (previous) {
          if (previous.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was used for a different reconciliation.');
          return { ...this.settlementView(previous), replayed: true };
        }
        if (!['APPROVED', 'PARTIALLY_PAID'].includes(expense.status)) throw new ConflictException('Only an approved expense with an outstanding balance can be reconciled.');
        const paid = expense.settlements.reduce((sum, settlement) => sum.plus(settlement.amount), new Prisma.Decimal(0));
        const balance = expense.amount.minus(paid);
        const paymentAmount = new Prisma.Decimal(amount);
        if (paymentAmount.gt(balance)) throw new ConflictException('The reconciled amount exceeds the approved expense balance.');
        const id = randomUUID();
        const receiptNumber = `ERCP-${id.replaceAll('-', '').slice(0, 20).toUpperCase()}`;
        const settlement = await tx.estateExpenseSettlement.create({ data: {
          id, estateId, expenseId: expense.id, verifiedById: actorId, amount: paymentAmount, currency: expense.currency,
          bankReference, normalizedBankReference, verificationNote, receiptNumber,
          receivedAt: new Date(`${input.receivedAt}T00:00:00.000Z`), idempotencyKeyHash, payloadHash,
        } });
        const nextStatus = paymentAmount.eq(balance) ? 'PAID' : 'PARTIALLY_PAID';
        await tx.estateExpenseRequest.update({ where: { id: expense.id }, data: { status: nextStatus } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId,
          action: 'estate_expense.bank_transfer_reconciled', targetType: 'estate_expense_settlement', targetId: settlement.id,
          outcome: 'success', occurredAt: new Date(), metadata: { expenseId, receiptNumber, amount: amount, currency: expense.currency, receivedAt: input.receivedAt } } });
        await this.notifications.enqueueUser(tx, { estateId, recipientUserId: expense.requesterUserId,
          eventKey: `expense:${expense.id}:settlement:${settlement.id}`, type: 'EXPENSE', title: 'Expense payment recorded',
          message: `${expense.code}: ${expense.currency} ${paymentAmount.toFixed(2)} was reconciled. Receipt reference ${receiptNumber}.`, sourceId: expense.id });
        return { ...this.settlementView(settlement), replayed: false };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      const code = (error as { code?: string }).code;
      if (code === 'P2002') throw new ConflictException('This bank reference or reconciliation was already recorded. Reload the expense before retrying.');
      throw error;
    }
  }

  private policyView(policy: { id: string; estateId: string; version: number; approvalStages: Prisma.JsonValue; allowUnbudgeted: boolean; preventRequesterApproval: boolean; requireDistinctApprovers: boolean; updatedAt: Date }) {
    return { id: policy.id, estateId: policy.estateId, version: policy.version, stages: policy.approvalStages,
      allowUnbudgeted: policy.allowUnbudgeted, preventRequesterApproval: policy.preventRequesterApproval,
      requireDistinctApprovers: policy.requireDistinctApprovers, updatedAt: policy.updatedAt.toISOString() };
  }

  private allowedCommands(row: { requesterUserId: string; budgetLineId?: string | null; status: string; approvalStageIndex: number; approvalPolicyVersion: number | null; amount: Prisma.Decimal; currency: string; payee: { currency: string; verifiedAt?: Date | null }; decisions: { actorUserId?: string }[] }, actorId: string, roles: string[], policy: { version: number; approvalStages: Prisma.JsonValue; allowUnbudgeted: boolean; preventRequesterApproval: boolean; requireDistinctApprovers: boolean } | null) {
    const commands: string[] = [];
    if (['APPROVED', 'PARTIALLY_PAID'].includes(row.status) && roles.some((role) => POLICY_ROLES.includes(role as (typeof POLICY_ROLES)[number]))) commands.push('reconcile');
    if (row.status === 'DRAFT' && row.requesterUserId === actorId && (policy?.allowUnbudgeted || row.budgetLineId)) return ['submit'];
    if (row.status !== 'PENDING_APPROVAL' || !policy || policy.version !== row.approvalPolicyVersion) return commands;
    const stages = policy.approvalStages as Array<{ role: string; maximumAmount: string | null }>;
    const stage = stages[row.approvalStageIndex];
    if (!stage || !roles.includes(stage.role)) return [];
    commands.push('reject');
    const distinct = !policy.requireDistinctApprovers || !row.decisions.some((decision) => decision.actorUserId === actorId);
    const notRequester = !policy.preventRequesterApproval || row.requesterUserId !== actorId;
    const belowLimit = !stage.maximumAmount || row.amount.lte(new Prisma.Decimal(stage.maximumAmount));
    const finalStage = row.approvalStageIndex + 1 >= stages.length;
    const verifiedPayee = row.payee.verifiedAt !== null && row.payee.currency === row.currency;
    if (distinct && notRequester && belowLimit && (!finalStage || verifiedPayee)) commands.unshift('approve');
    return commands;
  }

  private view(row: { id: string; estateId: string; code: string; description: string; amount: Prisma.Decimal; currency: string; neededBy: Date | null; status: string; approvalStageIndex: number; submittedAt: Date | null; createdAt: Date; category: { name: string; code: string }; payee: { displayName: string; reference: string; currency: string; verifiedAt?: Date | null }; budgetLine?: { id: string; category: { name: string; code: string } } | null; requester: { displayName: string }; decisions: { id: string; stageIndex: number; decision: string; reason: string | null; occurredAt: Date; actor: { displayName: string } }[]; settlements?: { amount: Prisma.Decimal; currency: string; receiptNumber: string; receivedAt: Date }[] }, paid = new Prisma.Decimal(0)) {
    return { id: row.id, estateId: row.estateId, code: row.code, description: row.description,
      amount: row.amount.toString(), currency: row.currency, neededBy: row.neededBy?.toISOString().slice(0, 10) ?? null,
      status: row.status.toLowerCase(), approvalStageIndex: row.approvalStageIndex,
      submittedAt: row.submittedAt?.toISOString() ?? null, createdAt: row.createdAt.toISOString(),
      category: row.category, payee: row.payee, budgetLine: row.budgetLine ? { id: row.budgetLine.id, category: row.budgetLine.category } : null, requesterName: row.requester.displayName,
      paidAmount: paid.toFixed(2), balance: Prisma.Decimal.max(row.amount.minus(paid), 0).toFixed(2),
      settlements: (row.settlements ?? []).map((item) => ({ amount: item.amount.toFixed(2), currency: item.currency, receiptNumber: item.receiptNumber, receivedAt: item.receivedAt.toISOString().slice(0, 10) })),
      decisions: row.decisions.map((item) => ({ stageIndex: item.stageIndex, decision: item.decision.toLowerCase(),
        reason: item.reason, occurredAt: item.occurredAt.toISOString(), actorName: item.actor.displayName })) };
  }

  private settlementView(row: { id: string; expenseId: string; amount: Prisma.Decimal; currency: string; receiptNumber: string; receivedAt: Date }) {
    return { id: row.id, expenseId: row.expenseId, amount: row.amount.toFixed(2), currency: row.currency, receiptNumber: row.receiptNumber, receivedAt: row.receivedAt.toISOString().slice(0, 10) };
  }

  private async requireRole(db: PrismaService | Prisma.TransactionClient, actorId: string, estateId: string, roles: readonly string[]) {
    const membership = await db.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', role: { in: [...roles] as never }, estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate finance access is required.');
  }

  private async audit(actorUserId: string, estateId: string, action: string, targetType: string, targetId: string) {
    await this.prisma.auditEvent.create({ data: { actorUserId, scope: 'estate', estateId, action, targetType, targetId, outcome: 'success', occurredAt: new Date() } });
  }
  private validMoney(value: string) { return /^\d{1,10}(?:\.\d{1,2})?$/.test(value); }
  private validDate(value: string) { const parsed = new Date(`${value}T00:00:00.000Z`); return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value; }
  private budgetLineValid(line: { categoryId: string; allocatedAmount: Prisma.Decimal; budget: { status: string; currency: string; periodStart: Date; periodEnd: Date } } | null, categoryId: string, currency: string, effectiveDate: Date) {
    return !!line && line.categoryId === categoryId && line.budget.status === 'APPROVED' && line.budget.currency === currency && effectiveDate >= line.budget.periodStart && effectiveDate <= line.budget.periodEnd;
  }
  private hash(value: string) { return createHash('sha256').update(value, 'utf8').digest('hex'); }
}
