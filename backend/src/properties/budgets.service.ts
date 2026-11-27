import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateEstateBudgetDto, DecideEstateBudgetDto } from './expenses.dto.js';

const FINANCE_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'FINANCE_MANAGER'] as const;
const APPROVER_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'FINANCE_MANAGER'] as const;

@Injectable()
export class EstateBudgetsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(actorId: string, estateId: string) {
    await this.requireRole(this.prisma, actorId, estateId, FINANCE_ROLES);
    const memberships = await this.prisma.estateMembership.findMany({ where: { estateId, userId: actorId, status: 'ACTIVE' }, select: { role: true } });
    const canDecide = memberships.some((membership) => APPROVER_ROLES.includes(membership.role as (typeof APPROVER_ROLES)[number]));
    const budgets = await this.prisma.estateBudget.findMany({
      where: { estateId }, orderBy: [{ periodStart: 'desc' }, { version: 'desc' }], take: 24,
      include: { lines: { include: { category: { select: { name: true, code: true } } } },
        createdBy: { select: { displayName: true } }, approvedBy: { select: { displayName: true } },
        decisions: { orderBy: { occurredAt: 'asc' }, include: { actor: { select: { displayName: true } } } } },
    });
    const lineIds = budgets.flatMap((budget) => budget.lines.map((line) => line.id));
    const commitments = lineIds.length ? await this.prisma.estateExpenseRequest.groupBy({
      by: ['budgetLineId'], where: { estateId, budgetLineId: { in: lineIds }, status: { in: ['APPROVED', 'PARTIALLY_PAID', 'PAID'] } },
      _sum: { amount: true },
    }) : [];
    const committedByLine = new Map(commitments.map((row) => [row.budgetLineId, row._sum.amount ?? new Prisma.Decimal(0)]));
    const paidRows = lineIds.length ? await this.prisma.estateExpenseRequest.findMany({
      where: { estateId, budgetLineId: { in: lineIds } }, select: { budgetLineId: true, settlements: { select: { amount: true } } },
    }) : [];
    const paidByLine = new Map<string, Prisma.Decimal>();
    for (const expense of paidRows) {
      if (!expense.budgetLineId) continue;
      const paid = expense.settlements.reduce((sum, settlement) => sum.plus(settlement.amount), new Prisma.Decimal(0));
      paidByLine.set(expense.budgetLineId, (paidByLine.get(expense.budgetLineId) ?? new Prisma.Decimal(0)).plus(paid));
    }
    const today = new Date().toISOString().slice(0, 10);
    return { estateId, items: budgets.map((budget) => ({
      id: budget.id, version: budget.version, periodStart: this.date(budget.periodStart), periodEnd: this.date(budget.periodEnd),
      currency: budget.currency, status: budget.status.toLowerCase(), createdBy: budget.createdBy.displayName,
      effectiveToday: budget.status === 'APPROVED' && this.date(budget.periodStart) <= today && this.date(budget.periodEnd) >= today,
      submittedAt: budget.submittedAt?.toISOString() ?? null, approvedAt: budget.approvedAt?.toISOString() ?? null,
      approvedBy: budget.approvedBy?.displayName ?? null,
      lines: budget.lines.map((line) => {
        const committed = committedByLine.get(line.id) ?? new Prisma.Decimal(0);
        const paid = paidByLine.get(line.id) ?? new Prisma.Decimal(0);
        return { id: line.id, categoryId: line.categoryId, category: line.category, allocated: line.allocatedAmount.toString(),
          committed: committed.toString(), paid: paid.toString(), available: Prisma.Decimal.max(line.allocatedAmount.minus(committed), 0).toString() };
      }),
      decisions: budget.decisions.map((decision) => ({ decision: decision.decision.toLowerCase(), reason: decision.reason,
        actorName: decision.actor.displayName, occurredAt: decision.occurredAt.toISOString() })),
      allowedCommands: budget.status === 'DRAFT' && budget.createdById === actorId ? ['submit'] :
        budget.status === 'PENDING_APPROVAL' && canDecide && budget.createdById !== actorId ? ['approve', 'reject'] : [],
    })) };
  }

  async create(actorId: string, estateId: string, input: CreateEstateBudgetDto) {
    await this.requireRole(this.prisma, actorId, estateId, APPROVER_ROLES);
    if (!this.validDate(input.periodStart) || !this.validDate(input.periodEnd) || input.periodStart > input.periodEnd) {
      throw new BadRequestException('Provide a valid inclusive budget period.');
    }
    if (!input.lines.every((line) => /^\d{1,10}(?:\.\d{1,2})?$/.test(line.allocatedAmount) && new Prisma.Decimal(line.allocatedAmount).gt(0))) {
      throw new BadRequestException('Budget line amounts must be positive and use no more than two decimal places.');
    }
    if (new Set(input.lines.map((line) => line.categoryId)).size !== input.lines.length) throw new BadRequestException('Each category can appear once in a budget.');
    const categoryIds = input.lines.map((line) => line.categoryId);
    const categoryCount = await this.prisma.estateExpenseCategory.count({ where: { estateId, id: { in: categoryIds }, active: true } });
    if (categoryCount !== categoryIds.length) throw new BadRequestException('All budget categories must be active in this estate.');
    const start = new Date(`${input.periodStart}T00:00:00.000Z`);
    const end = new Date(`${input.periodEnd}T00:00:00.000Z`);
    try {
      return await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${estateId}), 91524)`;
        const prior = await tx.estateBudget.findFirst({ where: { estateId, periodStart: start, periodEnd: end }, orderBy: { version: 'desc' } });
        if (prior?.status === 'PENDING_APPROVAL') throw new ConflictException('A budget version for this period is already awaiting a decision.');
        const row = await tx.estateBudget.create({ data: {
          estateId, periodStart: start, periodEnd: end, currency: input.currency,
          version: (prior?.version ?? 0) + 1, createdById: actorId,
          lines: { create: input.lines.map((line) => ({ estateId, categoryId: line.categoryId, allocatedAmount: new Prisma.Decimal(line.allocatedAmount) })) },
        }, include: { lines: { include: { category: { select: { name: true, code: true } } } } } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'budget.draft_created',
          targetType: 'estate_budget', targetId: row.id, outcome: 'success', occurredAt: new Date(), metadata: { version: row.version, periodStart: input.periodStart, periodEnd: input.periodEnd } } });
        return this.basic(row);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('Another budget version was created for this period. Refresh and try again.');
      throw error;
    }
  }

  async submit(actorId: string, estateId: string, budgetId: string) {
    return this.prisma.$transaction(async (tx) => {
      await this.requireRole(tx, actorId, estateId, APPROVER_ROLES);
      await tx.$queryRaw`SELECT id FROM estate_budgets WHERE id = ${budgetId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
      const budget = await tx.estateBudget.findFirst({ where: { id: budgetId, estateId }, include: { lines: true } });
      if (!budget || budget.createdById !== actorId) throw new NotFoundException('Draft budget not found in this estate.');
      if (budget.status !== 'DRAFT' || budget.lines.length === 0) throw new ConflictException('Only a non-empty draft budget can be submitted.');
      const submittedAt = new Date();
      const updated = await tx.estateBudget.update({ where: { id: budget.id }, data: { status: 'PENDING_APPROVAL', submittedAt } });
      await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'budget.submitted', targetType: 'estate_budget', targetId: budget.id, outcome: 'success', occurredAt: submittedAt } });
      return this.basic(updated);
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async decide(actorId: string, estateId: string, budgetId: string, input: DecideEstateBudgetDto) {
    const reason = input.reason?.trim() ?? '';
    if (input.decision === 'reject' && !reason) throw new BadRequestException('A reason is required to reject a budget.');
    return this.prisma.$transaction(async (tx) => {
      const membership = await tx.estateMembership.findFirst({ where: { estateId, userId: actorId, status: 'ACTIVE', role: { in: [...APPROVER_ROLES] }, estate: { status: 'ACTIVE' } }, select: { role: true } });
      if (!membership) throw new ForbiddenException('An active estate administrator or finance manager role is required.');
      await tx.$queryRaw`SELECT id FROM estate_budgets WHERE id = ${budgetId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
      const budget = await tx.estateBudget.findFirst({ where: { id: budgetId, estateId }, include: { lines: true } });
      if (!budget) throw new NotFoundException('Budget not found in this estate.');
      if (budget.status !== 'PENDING_APPROVAL') throw new ConflictException('Only a pending budget can receive a decision.');
      if (input.decision === 'approve' && budget.createdById === actorId) throw new ForbiddenException('The budget creator cannot approve their own budget.');
      if (input.decision === 'approve') {
        await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${estateId}), 91524)`;
        const overlapping = await tx.estateBudget.findFirst({ where: { estateId, status: 'APPROVED', id: { not: budget.id }, periodStart: { lte: budget.periodEnd }, periodEnd: { gte: budget.periodStart } }, select: { id: true } });
        if (overlapping) {
          const samePeriod = await tx.estateBudget.findFirst({ where: { id: overlapping.id, periodStart: budget.periodStart, periodEnd: budget.periodEnd }, include: { lines: true } });
          if (!samePeriod) throw new ConflictException('An approved budget overlaps this period. Revise only the exact same period.');
          const previousApprovals = await tx.estateExpenseRequest.count({ where: { estateId, budgetLineId: { in: samePeriod.lines.map((line) => line.id) }, status: 'APPROVED' } });
          if (previousApprovals > 0) throw new ConflictException('This approved budget already has committed expenses; revise it through a separate adjustment workflow.');
          await tx.estateBudget.update({ where: { id: samePeriod.id }, data: { status: 'SUPERSEDED' } });
        }
      }
      const occurredAt = new Date();
      const status = input.decision === 'approve' ? 'APPROVED' : 'REJECTED';
      const updated = await tx.estateBudget.update({ where: { id: budget.id }, data: {
        status, ...(input.decision === 'approve' ? { approvedById: actorId, approvedAt: occurredAt } : {}),
        decisions: { create: { actorUserId: actorId, decision: status, reason: reason || null, occurredAt } },
      } });
      await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: `budget.${input.decision}`,
        targetType: 'estate_budget', targetId: budget.id, outcome: 'success', reason: reason || null, occurredAt,
        metadata: { version: budget.version, periodStart: this.date(budget.periodStart), periodEnd: this.date(budget.periodEnd) } } });
      return this.basic(updated);
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  private basic(row: { id: string; estateId: string; version: number; periodStart: Date; periodEnd: Date; currency: string; status: string }) {
    return { id: row.id, estateId: row.estateId, version: row.version, periodStart: this.date(row.periodStart), periodEnd: this.date(row.periodEnd), currency: row.currency, status: row.status.toLowerCase() };
  }
  private date(value: Date) { return value.toISOString().slice(0, 10); }
  private validDate(value: string) { const parsed = new Date(`${value}T00:00:00.000Z`); return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value; }
  private async requireRole(db: PrismaService | Prisma.TransactionClient, actorId: string, estateId: string, roles: readonly string[]) {
    const membership = await db.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', role: { in: [...roles] as never }, estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate finance access is required.');
  }
}

