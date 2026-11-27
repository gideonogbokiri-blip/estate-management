import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma, type EstateRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

const MANAGEMENT_ROLES: EstateRole[] = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'FINANCE_MANAGER'];

type Range = { from?: string; to?: string };

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  private async membership(actorUserId: string, estateId: string, managementOnly = false) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: {
        userId: actorUserId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' },
        ...(managementOnly ? { role: { in: MANAGEMENT_ROLES } } : {}),
      },
      select: { role: true },
    });
    if (!membership) throw new ForbiddenException(managementOnly
      ? 'Active estate management access is required.'
      : 'Active estate membership is required.');
    return membership;
  }

  private date(value: string) {
    const parsed = new Date(`${value}T00:00:00.000Z`);
    if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== value) {
      throw new BadRequestException('Provide dates in YYYY-MM-DD format.');
    }
    return parsed;
  }

  private range(range: Range) {
    if (range.from && range.to && this.date(range.to) < this.date(range.from)) {
      throw new BadRequestException('The end date must be on or after the start date.');
    }
    if (range.from) this.date(range.from);
    if (range.to) this.date(range.to);
    return {
      from: range.from ? this.date(range.from) : null,
      to: range.to ? new Date(this.date(range.to).getTime() + 86_400_000 - 1) : null,
    };
  }

  async managerSummary(actorUserId: string, estateId: string) {
    await this.membership(actorUserId, estateId, true);
    const [invoices, rentSchedules, expenses, payouts, auditCount] = await Promise.all([
      this.prisma.estateInvoiceDraft.findMany({
        where: {
          estateId,
          dueDate: { lte: new Date() },
          status: { in: ['ISSUED', 'PARTIALLY_PAID'] },
        },
        select: { status: true, total: true, currency: true, dueDate: true },
      }),
      this.prisma.rentSchedule.findMany({
        where: { estateId }, select: { amount: true, currency: true, payments: { select: { amount: true } } },
      }),
      this.prisma.estateExpenseRequest.findMany({
        where: { estateId }, select: { status: true, amount: true, currency: true },
      }),
      this.prisma.estatePayoutRequest.findMany({
        where: { estateId }, select: { status: true, amount: true, currency: true },
      }),
      this.prisma.auditEvent.count({ where: { scope: 'estate', estateId } }),
    ]);

    const sum = <T>(rows: T[], pick: (row: T) => { toString(): string }) =>
      rows.reduce((total, row) => total.plus(pick(row).toString()), new Prisma.Decimal(0));
    const invoicesByStatus = (status: string) =>
      invoices.filter((row) => row.status === status);

    const rentEntitlement = sum(rentSchedules, (row) => row.amount);
    const rentCollected = sum(rentSchedules.flatMap((row) => row.payments), (row) => row.amount);
    const currency = invoices[0]?.currency
      ?? rentSchedules[0]?.currency
      ?? expenses[0]?.currency
      ?? 'NGN';

    return {
      estateId,
      generatedAt: new Date().toISOString(),
      currency,
      invoices: {
        total: invoices.length,
        issued: invoicesByStatus('ISSUED').length,
        partiallyPaid: invoicesByStatus('PARTIALLY_PAID').length,
        paid: invoicesByStatus('PAID').length,
        billed: sum(invoices, (row) => row.total).toString(),
      },
      rent: {
        schedules: rentSchedules.length,
        entitlement: rentEntitlement.toString(),
        collected: rentCollected.toString(),
        outstanding: rentEntitlement.minus(rentCollected).toString(),
      },
      expenses: {
        total: expenses.length,
        pending: expenses.filter((row) => row.status !== 'PAID').length,
        amount: sum(expenses, (row) => row.amount).toString(),
      },
      payouts: {
        total: payouts.length,
        pending: payouts.filter((row) => row.status === 'PENDING_APPROVAL').length,
        amount: sum(payouts, (row) => row.amount).toString(),
      },
      auditEvents: auditCount,
    };
  }

  async walletStatement(actorUserId: string, estateId: string, filters: Range & { walletId?: string }) {
    const membership = await this.membership(actorUserId, estateId);
    const isManager = MANAGEMENT_ROLES.includes(membership.role);
    const bounds = this.range(filters);
    const wallets = await this.prisma.estateWallet.findMany({
      where: { estateId, ...(isManager ? {} : { userId: actorUserId }) },
      select: { id: true, userId: true, currency: true, accountNumber: true, status: true },
      orderBy: { createdAt: 'asc' }, take: 100,
    });
    const visibleIds = new Set(wallets.map((wallet) => wallet.id));
    if (filters.walletId) {
      if (!visibleIds.has(filters.walletId)) throw new ForbiddenException('This fund account is not available to your account.');
      wallets.splice(0, wallets.length, ...wallets.filter((wallet) => wallet.id === filters.walletId));
    }
    const walletIds = wallets.map((wallet) => wallet.id);
    if (walletIds.length === 0) return { from: filters.from ?? null, to: filters.to ?? null, items: [], summary: { opening: '0.00', credits: '0.00', debits: '0.00', closing: '0.00' } };

    const before = bounds.from
      ? await this.prisma.estateWalletTransaction.findMany({
          where: { walletId: { in: walletIds }, status: 'posted', createdAt: { lt: bounds.from } },
          select: { type: true, amount: true }, take: 5000,
        })
      : [];
    const opening = before.reduce(
      (sum, row) => row.type === 'credit' ? sum.plus(row.amount) : sum.minus(row.amount),
      new Prisma.Decimal(0),
    );
    const rows = await this.prisma.estateWalletTransaction.findMany({
      where: {
        walletId: { in: walletIds }, status: 'posted',
        ...(bounds.from || bounds.to
          ? { createdAt: { ...(bounds.from ? { gte: bounds.from } : {}), ...(bounds.to ? { lte: bounds.to } : {}) } }
          : {}),
      },
      orderBy: { createdAt: 'asc' }, take: 2000,
    });
    const walletCurrency = new Map(wallets.map((wallet) => [wallet.id, wallet.currency]));
    let running = opening;
    let credits = new Prisma.Decimal(0);
    let debits = new Prisma.Decimal(0);
    const items = rows.map((row) => {
      const signed = row.type === 'credit' ? row.amount : row.amount.negated();
      running = running.plus(signed);
      if (row.type === 'credit') credits = credits.plus(row.amount);
      else debits = debits.plus(row.amount);
      return {
        id: row.id, walletId: row.walletId, currency: walletCurrency.get(row.walletId) ?? row.currency,
        date: row.createdAt.toISOString(), type: row.type, amount: row.amount.toString(),
        signedAmount: signed.toString(), balance: running.toString(),
        reference: row.reference, description: row.description, sourceType: row.sourceType,
      };
    });
    return {
      from: filters.from ?? null, to: filters.to ?? null, items,
      summary: { opening: opening.toString(), credits: credits.toString(), debits: debits.toString(), closing: running.toString() },
    };
  }

  async ledgerStatement(actorUserId: string, estateId: string, range: Range) {
    await this.membership(actorUserId, estateId, true);
    const bounds = this.range(range);
    const journals = await this.prisma.ledgerJournal.findMany({
      where: {
        estateId, status: 'posted',
        ...(bounds.from || bounds.to
          ? { occurredAt: { ...(bounds.from ? { gte: bounds.from } : {}), ...(bounds.to ? { lte: bounds.to } : {}) } }
          : {}),
      },
      include: { entries: true }, orderBy: { occurredAt: 'asc' }, take: 1000,
    });
    return {
      from: range.from ?? null, to: range.to ?? null,
      items: journals.map((journal) => ({
        id: journal.id, reference: journal.reference, sourceType: journal.sourceType,
        description: journal.description, currency: journal.currency,
        occurredAt: journal.occurredAt.toISOString(),
        entries: journal.entries.map((entry) => ({
          accountCode: entry.accountCode, direction: entry.direction,
          amount: entry.amount.toString(), currency: entry.currency,
        })),
      })),
    };
  }

  async audit(actorUserId: string, estateId: string, filters: Range & { action?: string; actorUserId?: string; outcome?: string }) {
    await this.membership(actorUserId, estateId, true);
    const bounds = this.range(filters);
    const where: Prisma.AuditEventWhereInput = {
      scope: 'estate', estateId,
      ...(filters.action ? { action: { contains: filters.action } } : {}),
      ...(filters.actorUserId ? { actorUserId: filters.actorUserId } : {}),
      ...(filters.outcome ? { outcome: filters.outcome } : {}),
      ...(bounds.from || bounds.to
        ? { occurredAt: { ...(bounds.from ? { gte: bounds.from } : {}), ...(bounds.to ? { lte: bounds.to } : {}) } }
        : {}),
    };
    const rows = await this.prisma.auditEvent.findMany({
      where, orderBy: { occurredAt: 'desc' }, take: 300,
      select: {
        id: true, actorUserId: true, action: true, targetType: true, targetId: true,
        outcome: true, reason: true, metadata: true, occurredAt: true,
        actor: { select: { displayName: true } },
      },
    });
    return { items: rows.map((row) => ({
      id: row.id, actorUserId: row.actorUserId, actorName: row.actor?.displayName ?? null,
      action: row.action, targetType: row.targetType, targetId: row.targetId,
      outcome: row.outcome, reason: row.reason, metadata: row.metadata,
      occurredAt: row.occurredAt.toISOString(),
    })) };
  }
}

