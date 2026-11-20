import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createHash, createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { LedgerService } from './ledger.service.js';

const PAYSTACK_BASE = process.env.PAYSTACK_BASE_URL ?? 'https://api.paystack.co';
const CURRENCY = 'NGN';

@Injectable()
export class EstateWalletService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  private demoMode() {
    return (process.env.FINANCIAL_DEMO_MODE ?? 'true').toLowerCase() !== 'false';
  }

  private key() {
    const secret = process.env.PAYSTACK_SECRET_KEY;
    if (!secret) {
      throw new ServiceUnavailableException(
        'Paystack is not configured. Add PAYSTACK_SECRET_KEY to enable account numbers and funding.',
      );
    }
    return secret;
  }

  async mine(userId: string) {
    const wallets = await this.prisma.estateWallet.findMany({
      where: { userId, estate: { status: 'ACTIVE', memberships: { some: { userId, status: 'ACTIVE' } } } },
      include: { estate: { select: { name: true } } },
      orderBy: { createdAt: 'desc' },
    });
    const items = [];
    for (const wallet of wallets) {
      const sums = await this.prisma.estateWalletTransaction.groupBy({
        by: ['type'],
        where: { walletId: wallet.id, status: 'posted' },
        _sum: { amount: true },
        orderBy: { type: 'asc' },
      });
      const credits = sums.find((row) => row.type === 'credit')?._sum.amount ?? new Prisma.Decimal(0);
      const debits = sums.find((row) => row.type === 'debit')?._sum.amount ?? new Prisma.Decimal(0);
      const transactions = await this.prisma.estateWalletTransaction.findMany({
        where: { walletId: wallet.id },
        orderBy: { createdAt: 'desc' },
        take: 30,
      });
      items.push({
        id: wallet.id,
        estateId: wallet.estateId,
        estateName: wallet.estate.name,
        currency: wallet.currency,
        accountNumber: wallet.accountNumber,
        bankName: wallet.bankName,
        accountName: wallet.accountName,
        status: wallet.status,
        balance: credits.sub(debits).toString(),
        transactions: transactions.map((tx) => ({
          id: tx.id, type: tx.type, amount: tx.amount.toString(), currency: tx.currency,
          reference: tx.reference, description: tx.description, sourceType: tx.sourceType,
          createdAt: tx.createdAt.toISOString(),
        })),
      });
    }
    return { items };
  }

  async provision(userId: string, estateId: string) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: { userId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' } },
      select: { id: true },
    });
    if (!membership) throw new ForbiddenException('Active estate membership is required.');
    const user = await this.prisma.user.findUnique({
      where: { id: userId }, select: { emailNormalized: true, displayName: true },
    });
    if (!user) throw new NotFoundException('Account not found.');

    let wallet = await this.prisma.estateWallet.findUnique({
      where: { estateId_userId_currency: { estateId, userId, currency: CURRENCY } },
    });
    if (wallet?.accountNumber) return this.walletView(wallet.id);

    let accountNumber: string;
    let bankName: string;
    let accountName: string;
    let providerReference: string;
    let demo = false;

    if (process.env.PAYSTACK_SECRET_KEY) {
      const secret = this.key();
      const parts = user.displayName.trim().split(/\s+/);
      const response = await fetch(`${PAYSTACK_BASE}/dedicated_virtual_accounts`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${secret}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: user.emailNormalized,
          first_name: parts[0] || 'Estate',
          last_name: parts.slice(1).join(' ') || 'Resident',
          preferred_bank: process.env.PAYSTACK_DVA_BANK ?? 'wema-bank',
        }),
      });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new ServiceUnavailableException(
          `Paystack could not provision an account: ${payload.message ?? response.status}`,
        );
      }
      const data = payload.data?.dedicated_account ?? payload.data ?? {};
      accountNumber = String(data.account_number ?? data.accountNumber ?? '').trim();
      bankName = String(data.bank_name ?? data.bankName ?? 'Paystack partner bank');
      accountName = String(data.account_name ?? data.accountName ?? user.displayName);
      providerReference = String(data.id ?? data.reference ?? '');
      if (!accountNumber) throw new ServiceUnavailableException('Paystack did not return an account number.');
    } else if (this.demoMode()) {
      demo = true;
      accountNumber = `DEMO-${Math.random().toString(36).slice(2, 8).toUpperCase()}`;
      bankName = 'LANCON Demo Bank (no transfers)';
      accountName = user.displayName;
      providerReference = 'DEMO_ACCOUNT';
    } else {
      throw new ServiceUnavailableException('Paystack is not configured and financial demo mode is disabled.');
    }
    wallet = await this.prisma.estateWallet.upsert({
      where: { estateId_userId_currency: { estateId, userId, currency: CURRENCY } },
      update: { accountNumber, bankName, accountName, providerReference, status: 'active' },
      create: { estateId, userId, currency: CURRENCY, accountNumber, bankName, accountName, providerReference, status: 'active' },
    });
    await this.prisma.auditEvent.create({ data: {
      actorUserId: userId, scope: 'estate', estateId, action: demo ? 'wallet.demo_account_provisioned' : 'wallet.account_provisioned',
      targetType: 'estate_wallet', targetId: wallet.id, outcome: 'success', occurredAt: new Date(),
      metadata: { demo },
    } });
    return { ...(await this.walletView(wallet.id)), demo };
  }

  async payRent(userId: string, estateId: string, invoiceId: string, amountText: string) {
    const amount = new Prisma.Decimal(amountText);
    if (amount.lte(0)) throw new BadRequestException('Amount must be positive.');
    const wallet = await this.prisma.estateWallet.findUnique({
      where: { estateId_userId_currency: { estateId, userId, currency: CURRENCY } },
      select: { id: true, status: true },
    });
    if (!wallet || wallet.status !== 'active') {
      throw new BadRequestException('An active fund account is required.');
    }
    const invoice = await this.prisma.estateInvoiceDraft.findFirst({
      where: { id: invoiceId, estateId, payerUserId: userId, status: { in: ['ISSUED', 'PARTIALLY_PAID'] } },
      select: { id: true, currency: true, total: true, invoiceNumber: true },
    });
    if (!invoice) throw new NotFoundException('Issued invoice not found for this account.');
    if (invoice.currency !== CURRENCY) throw new BadRequestException('Currency mismatch.');
    const paid = await this.prisma.estateInvoiceSettlement.aggregate({
      where: { invoiceId }, _sum: { amount: true },
    });
    const balance = invoice.total.sub(paid._sum.amount ?? new Prisma.Decimal(0));
    if (amount.gt(balance)) throw new BadRequestException('Amount exceeds the invoice balance.');

    const sums = await this.prisma.estateWalletTransaction.groupBy({
      by: ['type'], where: { walletId: wallet.id, status: 'posted' }, _sum: { amount: true },
    });
    const credits = sums.find((row) => row.type === 'credit')?._sum.amount ?? new Prisma.Decimal(0);
    const debits = sums.find((row) => row.type === 'debit')?._sum.amount ?? new Prisma.Decimal(0);
    if (credits.sub(debits).lt(amount)) throw new BadRequestException('Insufficient fund account balance.');

    const now = new Date();
    const reference = `WALLET-RENT-${invoiceId}-${now.getTime()}`;
    return this.prisma.$transaction(async (tx) => {
      // Lock the wallet row so concurrent debits cannot overspend.
      await tx.$queryRaw`SELECT id FROM estate_wallets WHERE id = ${wallet.id} FOR UPDATE`;
      const paidNow = await tx.estateInvoiceSettlement.aggregate({ where: { invoiceId }, _sum: { amount: true } });
      if (amount.gt(invoice.total.sub(paidNow._sum.amount ?? new Prisma.Decimal(0)))) {
        throw new BadRequestException('Amount exceeds the invoice balance.');
      }
      const sumsNow = await tx.estateWalletTransaction.groupBy({
        by: ['type'], where: { walletId: wallet.id, status: 'posted' }, _sum: { amount: true },
      });
      const creditNow = sumsNow.find((row) => row.type === 'credit')?._sum.amount ?? new Prisma.Decimal(0);
      const debitNow = sumsNow.find((row) => row.type === 'debit')?._sum.amount ?? new Prisma.Decimal(0);
      if (creditNow.sub(debitNow).lt(amount)) throw new BadRequestException('Insufficient fund account balance.');

      const journalId = await this.ledger.post(tx, {
        estateId,
        reference: `JRN-${reference}`,
        sourceType: 'wallet_rent_payment',
        sourceId: invoiceId,
        description: `Wallet rent payment for ${invoice.invoiceNumber}`,
        currency: CURRENCY,
        debitAccount: this.ledger.walletAccount(wallet.id),
        creditAccount: this.ledger.estateCollection(estateId, CURRENCY),
        amount,
        occurredAt: now,
      });
      await tx.estateWalletTransaction.create({ data: {
        walletId: wallet.id, estateId, type: 'debit', amount, currency: CURRENCY,
        reference, description: `Rent payment for ${invoice.invoiceNumber}`,
        sourceType: 'rent_payment', sourceId: invoiceId, status: 'posted', journalId,
      } });
      await tx.estateInvoiceSettlement.create({ data: {
        estateId, invoiceId, verifiedById: userId, amount, currency: CURRENCY,
        bankReference: reference, normalizedBankReference: reference.toLowerCase(),
        receiptNumber: `RCP-${randomUUID().replace(/-/g, '').slice(0, 16).toUpperCase()}`,
        receivedAt: now,
        verificationNote: 'Paid from the resident estate fund account.',
      } });
      await tx.auditEvent.create({ data: {
        actorUserId: userId, scope: 'estate', estateId, action: 'wallet.rent_paid',
        targetType: 'estate_invoice', targetId: invoiceId, outcome: 'success', occurredAt: now,
      } });
      return { paid: true, reference, amount: amount.toString(), journalId };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async createFundingIntent(userId: string, estateId: string, amountText: string,
    idempotencyKey: string | undefined) {
    const amount = new Prisma.Decimal(amountText);
    if (amount.lte(0) || amount.decimalPlaces() > 2) {
      throw new BadRequestException('Amount must be positive with at most two decimals.');
    }
    if (!idempotencyKey || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new BadRequestException('A valid Idempotency-Key is required.');
    }
    const membership = await this.prisma.estateMembership.findFirst({
      where: { userId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' } },
      select: { id: true },
    });
    if (!membership) throw new ForbiddenException('Active estate membership is required.');
    const wallet = await this.prisma.estateWallet.findUnique({
      where: { estateId_userId_currency: { estateId, userId, currency: CURRENCY } },
    });
    if (!wallet || wallet.status !== 'active' || !wallet.accountNumber) {
      throw new BadRequestException('Provision an active fund account before requesting funding.');
    }
    const hash = createHash('sha256').update(`funding-intent:v1:${idempotencyKey}`, 'utf8').digest('hex');
    const existing = await this.prisma.walletFundingIntent.findUnique({
      where: { userId_estateId_idempotencyKeyHash: { userId, estateId, idempotencyKeyHash: hash } },
    });
    if (existing) return { ...existing, replayed: true, accountNumber: wallet.accountNumber, bankName: wallet.bankName, accountName: wallet.accountName };
    const intent = await this.prisma.walletFundingIntent.create({ data: {
      walletId: wallet.id, estateId, userId, amount, currency: CURRENCY,
      status: 'awaiting_provider', providerReference: null,
      idempotencyKeyHash: hash,
      expiresAt: new Date(Date.now() + 30 * 60 * 1000),
    } });
    const reference = `FUND-${intent.id}`;
    await this.prisma.walletFundingIntent.update({ where: { id: intent.id }, data: { providerReference: reference } });
    await this.prisma.auditEvent.create({ data: {
      actorUserId: userId, scope: 'estate', estateId, action: 'wallet.funding_intent_created',
      targetType: 'wallet_funding_intent', targetId: intent.id, outcome: 'success', occurredAt: new Date(),
      metadata: { amount: amount.toString(), currency: CURRENCY },
    } });
    return { ...intent, providerReference: reference, replayed: false, accountNumber: wallet.accountNumber, bankName: wallet.bankName, accountName: wallet.accountName };
  }

  async payRentSchedule(userId: string, scheduleId: string, amountText: string) {
    const amount = new Prisma.Decimal(amountText);
    if (amount.lte(0)) throw new BadRequestException('Amount must be positive.');
    const schedule = await this.prisma.rentSchedule.findFirst({
      where: { id: scheduleId, tenantUserId: userId, status: { in: ['scheduled', 'partially_paid'] } },
    });
    if (!schedule) throw new NotFoundException('Rent schedule not found for this account.');
    if (amount.gt(schedule.amount)) throw new BadRequestException('Amount exceeds the scheduled rent.');
    const wallet = await this.prisma.estateWallet.findUnique({
      where: { estateId_userId_currency: { estateId: schedule.estateId, userId, currency: schedule.currency } },
      select: { id: true, status: true },
    });
    if (!wallet || wallet.status !== 'active') throw new BadRequestException('An active fund account is required.');

    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM estate_wallets WHERE id = ${wallet.id} FOR UPDATE`;
      const sums = await tx.estateWalletTransaction.groupBy({
        by: ['type'], where: { walletId: wallet.id, status: 'posted' }, _sum: { amount: true },
      });
      const credits = sums.find((row) => row.type === 'credit')?._sum?.amount ?? new Prisma.Decimal(0);
      const debits = sums.find((row) => row.type === 'debit')?._sum?.amount ?? new Prisma.Decimal(0);
      if (credits.sub(debits).lt(amount)) throw new BadRequestException('Insufficient fund account balance.');

      const paid = await tx.rentPayment.aggregate({ where: { scheduleId }, _sum: { amount: true } });
      if (amount.gt(schedule.amount.sub(paid._sum.amount ?? new Prisma.Decimal(0)))) {
        throw new BadRequestException('Amount exceeds the outstanding rent.');
      }
      const now = new Date();
      const reference = `RENT-WALLET-${schedule.id}-${now.getTime()}`;
      const journalId = await this.ledger.post(tx, {
        estateId: schedule.estateId,
        reference: `JRN-${reference}`,
        sourceType: 'rent_wallet_payment',
        sourceId: schedule.id,
        description: `Rent payment for tenancy ${schedule.tenancyId}`,
        currency: schedule.currency,
        debitAccount: this.ledger.walletAccount(wallet.id),
        creditAccount: this.ledger.landlordPayable(schedule.payeeUserId),
        amount,
        occurredAt: now,
      });
      await tx.estateWalletTransaction.create({ data: {
        walletId: wallet.id, estateId: schedule.estateId, type: 'debit', amount,
        currency: schedule.currency, reference,
        description: `Rent payment for schedule ${schedule.id}`,
        sourceType: 'rent_payment', sourceId: schedule.id, status: 'posted', journalId,
      } });
      const receiptNumber = `RCP-${randomUUID().replace(/-/g, '').slice(0, 16).toUpperCase()}`;
      await tx.rentPayment.create({ data: {
        scheduleId, estateId: schedule.estateId, amount, currency: schedule.currency,
        paidBy: userId, paymentReference: reference, receiptNumber, receivedAt: now,
        sourceType: 'wallet',
      } });
      const totalPaid = (paid._sum.amount ?? new Prisma.Decimal(0)).add(amount);
      await tx.rentSchedule.update({ where: { id: scheduleId }, data: {
        status: totalPaid.gte(schedule.amount) ? 'paid' : 'partially_paid',
      } });
      await tx.auditEvent.create({ data: {
        actorUserId: userId, scope: 'estate', estateId: schedule.estateId,
        action: 'rent.wallet_payment', targetType: 'rent_schedule', targetId: scheduleId,
        outcome: 'success', occurredAt: now, metadata: { amount: amount.toString(), journalId },
      } });
      return { paid: true, reference, receiptNumber, amount: amount.toString(), journalId };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async demoCredit(userId: string, intentId: string) {
    if (!this.demoMode()) {
      throw new BadRequestException('Financial demo mode is disabled.');
    }
    if (!intentId) throw new BadRequestException('A funding intent is required.');
    const intent = await this.prisma.walletFundingIntent.findUnique({ where: { id: intentId } });
    if (!intent || intent.userId !== userId) throw new NotFoundException('Funding intent not found.');
    if (intent.status !== 'awaiting_provider') throw new ConflictException('Funding intent is no longer awaiting funding.');
    if (intent.expiresAt <= new Date()) {
      await this.prisma.walletFundingIntent.update({ where: { id: intent.id }, data: { status: 'expired' } });
      throw new ConflictException('Funding intent has expired.');
    }
    const wallet = await this.prisma.estateWallet.findUnique({ where: { id: intent.walletId } });
    if (!wallet) throw new NotFoundException('Wallet not found.');
    const now = new Date();
    return this.prisma.$transaction(async (tx) => {
      const journalId = await this.ledger.post(tx, {
        estateId: wallet.estateId,
        reference: `JRN-DEMO-FUND-${intent.providerReference ?? intent.id}`,
        sourceType: 'demo_funding',
        sourceId: intent.id,
        description: 'Demo wallet funding (no real money received)',
        currency: wallet.currency,
        debitAccount: 'DEMO_FUNDING_CLEARING:NGN',
        creditAccount: this.ledger.walletAccount(wallet.id),
        amount: intent.amount,
        occurredAt: now,
      });
      await tx.estateWalletTransaction.create({ data: {
        walletId: wallet.id, estateId: wallet.estateId, type: 'credit', amount: intent.amount,
        currency: wallet.currency, reference: `DEMO-FUND-${intent.id}`,
        description: 'Demo funding (no real money)', sourceType: 'demo_funding',
        sourceId: intent.id, status: 'posted', journalId,
      } });
      await tx.walletFundingIntent.update({ where: { id: intent.id }, data: { status: 'completed' } });
      await tx.auditEvent.create({ data: {
        actorUserId: userId, scope: 'estate', estateId: wallet.estateId,
        action: 'wallet.demo_funding_posted', targetType: 'wallet_funding_intent', targetId: intent.id,
        outcome: 'success', occurredAt: now, metadata: { amount: intent.amount.toString(), demo: true },
      } });
      return { credited: true, demo: true, amount: intent.amount.toString(), journalId };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async handleWebhook(rawBody: Buffer, signature: string | undefined) {
    const secret = this.key();
    if (!signature) throw new BadRequestException('Missing webhook signature.');
    const expected = createHmac('sha512', secret).update(rawBody).digest('hex');
    const provided = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expected);
    if (provided.length !== expectedBuffer.length || !timingSafeEqual(provided, expectedBuffer)) {
      throw new BadRequestException('Invalid webhook signature.');
    }
    const event = JSON.parse(rawBody.toString('utf8'));
    const eventId = String(event.id ?? '').trim();
    if (!eventId) throw new BadRequestException('Provider event id is required.');
    const existingEvent = await this.prisma.providerWebhookEvent.findUnique({
      where: { provider_eventId: { provider: 'paystack', eventId } },
    });
    if (existingEvent?.status === 'processed') return { credited: false, replayed: true };

    const supported = ['dedicatedvirtualaccount.success', 'transfer.success'];
    if (!supported.includes(event.event)) {
      await this.prisma.providerWebhookEvent.create({ data: {
        provider: 'paystack', eventId, eventType: String(event.event ?? ''),
        status: 'ignored', payload: event, processedAt: new Date(),
      } });
      return { ignored: event.event };
    }
    const data = event.data ?? {};
    const accountNumber = String(data.account_number ?? data.accountNumber ?? '').trim();
    const providerReference = String(data.reference ?? '').trim();
    const kobo = Number(data.amount ?? 0);
    const currency = String(data.currency ?? CURRENCY).toUpperCase();
    const amount = new Prisma.Decimal(Number.isFinite(kobo) && kobo > 0 ? (kobo / 100).toFixed(2) : '0');

    const intent = providerReference
      ? await this.prisma.walletFundingIntent.findFirst({ where: { providerReference } })
      : null;
    const wallet = await this.prisma.estateWallet.findUnique({ where: { accountNumber } });
    const eventRecord = await this.prisma.providerWebhookEvent.create({ data: {
      provider: 'paystack', eventId, eventType: String(event.event),
      status: 'pending', payload: event,
    } });

    let failure: string | null = null;
    if (!wallet) failure = 'unknown_account';
    else if (!intent) failure = 'no_matching_funding_intent';
    else if (wallet.id !== intent.walletId) failure = 'wallet_mismatch';
    else if (currency !== wallet.currency || currency !== intent.currency) failure = 'currency_mismatch';
    else if (amount.lte(0) || amount.toString() !== intent.amount.toString()) failure = 'amount_mismatch';
    else if (intent.status !== 'awaiting_provider') failure = 'intent_not_awaiting_provider';
    else if (data.account_name && String(data.account_name).trim().toLowerCase() !== (wallet.accountName ?? '').toLowerCase()) failure = 'recipient_mismatch';

    if (failure) {
      await this.prisma.providerWebhookEvent.update({ where: { id: eventRecord.id },
        data: { status: 'quarantined', error: failure, processedAt: new Date() } });
      return { quarantined: true, reason: failure };
    }

    const creditWallet = wallet!;
    const matchedIntent = intent!;
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      const journalId = await this.ledger.post(tx, {
        estateId: creditWallet.estateId,
        reference: `JRN-FUND-${providerReference}`,
        sourceType: 'paystack_funding',
        sourceId: providerReference,
        description: 'Wallet funding received via Paystack',
        currency: creditWallet.currency,
        debitAccount: this.ledger.providerClearing('paystack', creditWallet.currency),
        creditAccount: this.ledger.walletAccount(creditWallet.id),
        amount,
        occurredAt: now,
      });
      await tx.estateWalletTransaction.create({ data: {
        walletId: creditWallet.id, estateId: creditWallet.estateId, type: 'credit', amount,
        currency: creditWallet.currency, reference: providerReference,
        description: 'Funding received to estate fund account',
        sourceType: 'paystack_webhook', sourceId: providerReference, status: 'posted', journalId,
      } });
      await tx.walletFundingIntent.update({ where: { id: matchedIntent.id }, data: { status: 'completed' } });
      await tx.providerWebhookEvent.update({ where: { id: eventRecord.id }, data: { status: 'processed', processedAt: now } });
      await tx.auditEvent.create({ data: {
        actorUserId: null, scope: 'estate', estateId: creditWallet.estateId,
        action: 'creditWallet.funding_received', targetType: 'estate_wallet', targetId: creditWallet.id,
        outcome: 'success', occurredAt: now, metadata: { reference: providerReference, amount: amount.toString() },
      } });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    return { credited: true, reference: providerReference, amount: amount.toString() };
  }

  private async walletView(walletId: string) {
    const wallet = await this.prisma.estateWallet.findUniqueOrThrow({
      where: { id: walletId }, include: { estate: { select: { name: true } } },
    });
    const sums = await this.prisma.estateWalletTransaction.groupBy({
      by: ['type'], where: { walletId }, _sum: { amount: true },
    });
    const credits = sums.find((row) => row.type === 'credit')?._sum.amount ?? new Prisma.Decimal(0);
    const debits = sums.find((row) => row.type === 'debit')?._sum.amount ?? new Prisma.Decimal(0);
    return {
      id: wallet.id, estateId: wallet.estateId, estateName: wallet.estate.name,
      currency: wallet.currency, accountNumber: wallet.accountNumber, bankName: wallet.bankName,
      accountName: wallet.accountName, status: wallet.status,
      balance: credits.sub(debits).toString(),
    };
  }
}
