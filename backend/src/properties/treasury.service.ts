import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { LedgerService } from './ledger.service.js';

const MANAGEMENT_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'FINANCE_MANAGER'];

@Injectable()
export class EstateTreasuryService {
  constructor(private readonly prisma: PrismaService, private readonly ledger: LedgerService) {}

  async summary(actorUserId: string, estateId: string) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: { estateId, userId: actorUserId, status: 'ACTIVE', role: { in: MANAGEMENT_ROLES as never } },
      select: { id: true },
    });
    if (!membership) throw new ForbiddenException('Estate finance access is required.');

    const [collectionCredits, collectionDebits, invoices, expensesByStatus, pendingFunding, exceptions, walletRows] =
      await this.prisma.$transaction([
        this.prisma.ledgerEntry.aggregate({
          where: { accountCode: this.ledger.estateCollection(estateId, 'NGN'), direction: 'credit' },
          _sum: { amount: true },
        }),
        this.prisma.ledgerEntry.aggregate({
          where: { accountCode: this.ledger.estateCollection(estateId, 'NGN'), direction: 'debit' },
          _sum: { amount: true },
        }),
        this.prisma.estateInvoiceDraft.findMany({
          where: { estateId, status: { in: ['ISSUED', 'PARTIALLY_PAID'] } },
          select: { id: true, total: true, currency: true },
        }),
        this.prisma.estateExpenseRequest.groupBy({
          by: ['status'], where: { estateId }, _sum: { amount: true }, _count: { _all: true },
          orderBy: { status: 'asc' },
        }),
        this.prisma.walletFundingIntent.count({ where: { estateId, status: 'awaiting_provider' } }),
        this.prisma.providerWebhookEvent.count({ where: { status: 'quarantined' } }),
        this.prisma.estateWalletTransaction.groupBy({
          by: ['type'], where: { estateId, status: 'posted' }, orderBy: { type: 'asc' }, _sum: { amount: true },
        }),
      ]);

    let outstanding = new Prisma.Decimal(0);
    for (const invoice of invoices) {
      const paid = await this.prisma.estateInvoiceSettlement.aggregate({ where: { invoiceId: invoice.id }, _sum: { amount: true } });
      outstanding = outstanding.add(invoice.total.sub(paid._sum.amount ?? new Prisma.Decimal(0)));
    }
    const walletCredits = walletRows.find((row) => row.type === 'credit')?._sum?.amount ?? new Prisma.Decimal(0);
    const walletDebits = walletRows.find((row) => row.type === 'debit')?._sum?.amount ?? new Prisma.Decimal(0);

    return {
      estateId,
      currency: 'NGN',
      collections: (collectionCredits._sum.amount ?? new Prisma.Decimal(0))
        .sub(collectionDebits._sum.amount ?? new Prisma.Decimal(0)).toString(),
      walletBalances: walletCredits.sub(walletDebits).toString(),
      outstandingInvoices: outstanding.toString(),
      pendingSettlements: pendingFunding,
      reconciliationExceptions: exceptions,
      expenses: expensesByStatus.map((row) => ({
        status: row.status,
        count: (row._count as { _all: number })._all,
        total: row._sum?.amount?.toString() ?? '0',
      })),
    };
  }
}

