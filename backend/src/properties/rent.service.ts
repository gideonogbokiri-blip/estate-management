import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

const MANAGEMENT_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'FINANCE_MANAGER'];

function addMonths(date: Date, count: number) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + count, 1));
}
function lastDay(year: number, month: number) {
  return new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
}
function dateOnly(value: Date) {
  return value.toISOString().slice(0, 10);
}

@Injectable()
export class RentService {
  constructor(private readonly prisma: PrismaService) {}

  private async membership(actorUserId: string, estateId: string) {
    return this.prisma.estateMembership.findFirst({
      where: { estateId, userId: actorUserId, status: 'ACTIVE', estate: { status: 'ACTIVE' } },
      select: { role: true },
    });
  }

  async generate(actorUserId: string, estateId: string, from?: string, months = 3) {
    const membership = await this.membership(actorUserId, estateId);
    if (!MANAGEMENT_ROLES.includes(membership?.role ?? '')) {
      throw new ForbiddenException('Estate finance access is required.');
    }
    const start = from ? new Date(`${from}T00:00:00.000Z`) : addMonths(new Date(), 0);
    if (Number.isNaN(start.getTime())) throw new ForbiddenException('Invalid start date.');
    const horizon = addMonths(start, Math.max(1, Math.min(months, 24)));
    const tenancies = await this.prisma.estateTenancy.findMany({
      where: {
        estateId,
        status: 'ACTIVE',
        effectiveFrom: { lte: horizon },
        OR: [{ effectiveTo: null }, { effectiveTo: { gte: start } }],
      },
    });
    let created = 0;
    let skipped = 0;
    for (const tenancy of tenancies) {
      const increment = { MONTHLY: 1, QUARTERLY: 3, ANNUALLY: 12 }[tenancy.rentFrequency];
      const periodStartBase = new Date(Date.UTC(
        tenancy.effectiveFrom.getUTCFullYear(), tenancy.effectiveFrom.getUTCMonth(), 1,
      ));
      let cursor = new Date(Math.max(periodStartBase.getTime(), start.getTime()));
      cursor = new Date(Date.UTC(cursor.getUTCFullYear(), cursor.getUTCMonth(), 1));
      while (cursor < horizon) {
        const end = addMonths(cursor, increment);
        if (tenancy.effectiveTo && cursor >= tenancy.effectiveTo) break;
        const dueDay = Math.min(tenancy.rentDueDay, lastDay(cursor.getUTCFullYear(), cursor.getUTCMonth()));
        const dueDate = new Date(Date.UTC(cursor.getUTCFullYear(), cursor.getUTCMonth(), dueDay));
        const idempotencyKey = `${tenancy.id}:${dateOnly(cursor)}`;
        const existing = await this.prisma.rentSchedule.findUnique({ where: { idempotencyKey } });
        if (existing) {
          skipped += 1;
        } else {
          await this.prisma.rentSchedule.create({ data: {
            estateId, tenancyId: tenancy.id, tenantUserId: tenancy.tenantUserId,
            payeeUserId: tenancy.payeeUserId, propertyId: tenancy.propertyId,
            amount: tenancy.rentAmount, currency: tenancy.currency, frequency: tenancy.rentFrequency,
            periodStart: cursor, periodEnd: new Date(end.getTime() - 24 * 60 * 60 * 1000),
            dueDate, status: 'scheduled', idempotencyKey,
          } });
          created += 1;
        }
        cursor = end;
      }
    }
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'estate', estateId, action: 'rent.schedule_generated',
      targetType: 'rent_schedule', targetId: estateId, outcome: 'success', occurredAt: new Date(),
      metadata: { created, skipped, from: dateOnly(start) },
    } });
    return { created, skipped, tenancies: tenancies.length };
  }

  async list(actorUserId: string, estateId: string, filters: { tenantUserId?: string; payeeUserId?: string }) {
    const membership = await this.membership(actorUserId, estateId);
    const isManager = MANAGEMENT_ROLES.includes(membership?.role ?? '');
    const where: Prisma.RentScheduleWhereInput = { estateId };
    if (!isManager) {
      where.OR = [{ tenantUserId: actorUserId }, { payeeUserId: actorUserId }];
    }
    if (filters.tenantUserId) where.tenantUserId = filters.tenantUserId;
    if (filters.payeeUserId) where.payeeUserId = filters.payeeUserId;
    const rows = await this.prisma.rentSchedule.findMany({
      where, include: { payments: true }, orderBy: { dueDate: 'asc' }, take: 200,
    });
    const today = new Date();
    return { items: rows.map((row) => {
      const paid = row.payments.reduce((sum, item) => sum.add(item.amount), new Prisma.Decimal(0));
      const balance = row.amount.sub(paid);
      return {
        id: row.id, estateId: row.estateId, tenancyId: row.tenancyId,
        tenantUserId: row.tenantUserId, payeeUserId: row.payeeUserId, propertyId: row.propertyId,
        amount: row.amount.toString(), currency: row.currency, frequency: row.frequency,
        periodStart: dateOnly(row.periodStart), periodEnd: dateOnly(row.periodEnd),
        dueDate: dateOnly(row.dueDate), status: balance.lte(0) ? 'paid' : balance.lt(row.amount) ? 'partially_paid' : 'scheduled',
        paid: paid.toString(), balance: balance.toString(),
        isOverdue: balance.gt(0) && row.dueDate < today,
        receipts: row.payments.map((payment) => ({ reference: payment.paymentReference, receipt: payment.receiptNumber, amount: payment.amount.toString() })),
      };
    }) };
  }

  async landlordSummary(actorUserId: string, estateId: string) {
    const membership = await this.membership(actorUserId, estateId);
    const isManager = MANAGEMENT_ROLES.includes(membership?.role ?? '');
    const rows = await this.prisma.rentSchedule.findMany({
      where: { estateId, ...(isManager ? {} : { payeeUserId: actorUserId }) },
      include: { payments: true },
    });
    const byPayee = new Map<string, { entitlement: Prisma.Decimal; collected: Prisma.Decimal; outstanding: Prisma.Decimal }>();
    for (const row of rows) {
      const entry = byPayee.get(row.payeeUserId)
        ?? { entitlement: new Prisma.Decimal(0), collected: new Prisma.Decimal(0), outstanding: new Prisma.Decimal(0) };
      const paid = row.payments.reduce((sum, item) => sum.add(item.amount), new Prisma.Decimal(0));
      entry.entitlement = entry.entitlement.add(row.amount);
      entry.collected = entry.collected.add(paid);
      entry.outstanding = entry.outstanding.add(row.amount.sub(paid));
      byPayee.set(row.payeeUserId, entry);
    }
    const payeeIds = [...byPayee.keys()];
    const users = await this.prisma.user.findMany({ where: { id: { in: payeeIds } }, select: { id: true, displayName: true } });
    const names = new Map(users.map((user) => [user.id, user.displayName]));
    return { items: [...byPayee.entries()].map(([payeeUserId, totals]) => ({
      payeeUserId, payeeName: names.get(payeeUserId) ?? 'Landlord',
      entitlement: totals.entitlement.toString(), collected: totals.collected.toString(),
      outstanding: totals.outstanding.toString(),
    })) };
  }
}

