import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface LedgerPosting {
  estateId?: string | null;
  reference: string;
  sourceType: string;
  sourceId?: string | null;
  description: string;
  currency: string;
  debitAccount: string;
  creditAccount: string;
  amount: Prisma.Decimal;
  occurredAt?: Date;
}

@Injectable()
export class LedgerService {
  constructor(private readonly prisma: PrismaService) {}

  async post(tx: Prisma.TransactionClient, input: LedgerPosting): Promise<string> {
    if (input.amount.lte(0)) throw new BadRequestException('Ledger amount must be positive.');
    if (input.debitAccount === input.creditAccount) {
      throw new BadRequestException('Debit and credit accounts must differ.');
    }
    const journal = await tx.ledgerJournal.create({ data: {
      estateId: input.estateId ?? null,
      reference: input.reference,
      sourceType: input.sourceType,
      sourceId: input.sourceId ?? null,
      description: input.description,
      currency: input.currency,
      status: 'posted',
      occurredAt: input.occurredAt ?? new Date(),
    }, select: { id: true } });
    await tx.ledgerEntry.createMany({ data: [
      { journalId: journal.id, accountCode: input.debitAccount, direction: 'debit', amount: input.amount, currency: input.currency },
      { journalId: journal.id, accountCode: input.creditAccount, direction: 'credit', amount: input.amount, currency: input.currency },
    ] });
    return journal.id;
  }

  async reverse(tx: Prisma.TransactionClient, journalId: string, reason: string) {
    const original = await tx.ledgerJournal.findUnique({
      where: { id: journalId }, include: { entries: true },
    });
    if (!original) throw new NotFoundException('Journal not found.');
    if (original.status === 'reversed') throw new BadRequestException('Journal is already reversed.');
    if (!reason.trim()) throw new BadRequestException('A reversal reason is required.');
    const debit = original.entries.find((entry) => entry.direction === 'debit');
    const credit = original.entries.find((entry) => entry.direction === 'credit');
    if (!debit || !credit || debit.amount.toString() !== credit.amount.toString()) {
      throw new BadRequestException('The original journal is not balanced.');
    }
    const reversalId = await this.post(tx, {
      estateId: original.estateId,
      reference: `REVERSAL-${original.reference}`,
      sourceType: 'reversal',
      sourceId: original.id,
      description: `Reversal of ${original.reference}: ${reason}`.slice(0, 300),
      currency: original.currency,
      debitAccount: credit.accountCode,
      creditAccount: debit.accountCode,
      amount: debit.amount,
    });
    await tx.ledgerJournal.update({ where: { id: original.id }, data: { status: 'reversed', reversedByJournalId: reversalId } });
    return reversalId;
  }

  walletAccount(walletId: string) {
    return `WALLET:${walletId}`;
  }

  providerClearing(provider: string, currency: string) {
    return `PROVIDER_CLEARING:${provider.toUpperCase()}:${currency}`;
  }

  estateCollection(estateId: string, currency: string) {
    return `ESTATE_COLLECTION:${estateId}:${currency}`;
  }

  invoiceReceivable(invoiceId: string) {
    return `INVOICE_RECEIVABLE:${invoiceId}`;
  }
}
