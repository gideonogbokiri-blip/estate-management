import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { LedgerService } from './ledger.service.js';

const ADMIN = 'ESTATE_ADMINISTRATOR';
const FINANCE = 'FINANCE_MANAGER';
const CURRENCY = 'NGN';

@Injectable()
export class EstatePayoutService {
  constructor(private readonly prisma: PrismaService, private readonly ledger: LedgerService) {}

  private async membership(actorUserId: string, estateId: string) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: { estateId, userId: actorUserId, status: 'ACTIVE', estate: { status: 'ACTIVE' } },
      select: { role: true },
    });
    return membership;
  }

  async policy(actorUserId: string, estateId: string) {
    await this.membership(actorUserId, estateId);
    const stored = await this.prisma.estatePayoutPolicy.findUnique({ where: { estateId } });
    return stored ?? { estateId, threshold: new Prisma.Decimal('100000.00'), requiredApprovals: 1 };
  }

  async updatePolicy(actorUserId: string, estateId: string, threshold: string, requiredApprovals: number) {
    const membership = await this.membership(actorUserId, estateId);
    if (membership?.role !== ADMIN) throw new ForbiddenException('Only the estate administrator can change payout policy.');
    const amount = new Prisma.Decimal(threshold);
    if (amount.lte(0)) throw new BadRequestException('Threshold must be positive.');
    if (!Number.isInteger(requiredApprovals) || requiredApprovals < 1 || requiredApprovals > 3) {
      throw new BadRequestException('Required approvals must be between 1 and 3.');
    }
    const policy = await this.prisma.estatePayoutPolicy.upsert({
      where: { estateId },
      update: { threshold: amount, requiredApprovals, updatedBy: actorUserId },
      create: { estateId, threshold: amount, requiredApprovals, updatedBy: actorUserId },
    });
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'estate', estateId, action: 'payout.policy_updated',
      targetType: 'estate_payout_policy', targetId: policy.id, outcome: 'success', occurredAt: new Date(),
      metadata: { threshold, requiredApprovals },
    } });
    return policy;
  }

  async createBeneficiary(actorUserId: string, estateId: string,
    input: { displayName: string; bankName: string; accountNumber: string; bankCode: string }) {
    const membership = await this.membership(actorUserId, estateId);
    if (![ADMIN, FINANCE].includes(membership?.role ?? '')) {
      throw new ForbiddenException('Estate finance access is required.');
    }
    const beneficiary = await this.prisma.estatePayoutBeneficiary.create({ data: {
      estateId, displayName: input.displayName, bankName: input.bankName,
      accountNumber: input.accountNumber, accountReference: input.bankCode, createdBy: actorUserId,
    } });
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'estate', estateId, action: 'payout.beneficiary_created',
      targetType: 'estate_payout_beneficiary', targetId: beneficiary.id, outcome: 'success', occurredAt: new Date(),
    } });
    return beneficiary;
  }

  async verifyBeneficiary(actorUserId: string, beneficiaryId: string) {
    const beneficiary = await this.prisma.estatePayoutBeneficiary.findUnique({ where: { id: beneficiaryId } });
    if (!beneficiary) throw new NotFoundException('Beneficiary not found.');
    const membership = await this.membership(actorUserId, beneficiary.estateId);
    if (membership?.role !== ADMIN) throw new ForbiddenException('Only the estate administrator can verify beneficiaries.');
    const verified = await this.prisma.estatePayoutBeneficiary.update({ where: { id: beneficiaryId },
      data: { verifiedAt: new Date(), verifiedBy: actorUserId } });
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'estate', estateId: beneficiary.estateId, action: 'payout.beneficiary_verified',
      targetType: 'estate_payout_beneficiary', targetId: beneficiaryId, outcome: 'success', occurredAt: new Date(),
    } });
    return verified;
  }

  async listBeneficiaries(actorUserId: string, estateId: string) {
    await this.membership(actorUserId, estateId);
    return this.prisma.estatePayoutBeneficiary.findMany({ where: { estateId, active: true }, orderBy: { displayName: 'asc' } });
  }

  async create(actorUserId: string, estateId: string,
    input: { beneficiaryId: string; amount: string; currency: string; purpose: string; fundCategory?: string },
    idempotencyKey: string | undefined,
    requestHash: string) {
    const membership = await this.membership(actorUserId, estateId);
    if (membership?.role !== FINANCE && membership?.role !== ADMIN) {
      throw new ForbiddenException('Only estate finance staff can initiate payouts.');
    }
    if (!idempotencyKey || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new BadRequestException('A valid Idempotency-Key is required.');
    }
    const amount = new Prisma.Decimal(input.amount);
    if (amount.lte(0) || amount.decimalPlaces() > 2) throw new BadRequestException('Amount must be positive.');
    if (input.currency !== CURRENCY) throw new BadRequestException('Only NGN payouts are supported.');
    const beneficiary = await this.prisma.estatePayoutBeneficiary.findFirst({
      where: { id: input.beneficiaryId, estateId, active: true, verifiedAt: { not: null } },
    });
    if (!beneficiary) throw new BadRequestException('A verified estate beneficiary is required.');

    const hash = createHash('sha256').update(`payout:v1:${idempotencyKey}`, 'utf8').digest('hex');
    const existing = await this.prisma.estatePayoutRequest.findUnique({
      where: { estateId_initiatedBy_idempotencyKeyHash: { estateId, initiatedBy: actorUserId, idempotencyKeyHash: hash } },
    });
    if (existing) return { ...existing, replayed: true };

    const policy = await this.policy(actorUserId, estateId);
    const requiredApprovals = amount.gte(policy!.threshold) ? Math.max(policy!.requiredApprovals, 2) : 1;
    return this.prisma.$transaction(async (tx) => {
      const collections = await tx.ledgerEntry.aggregate({
        where: { accountCode: this.ledger.estateCollection(estateId, CURRENCY), direction: 'credit' },
        _sum: { amount: true },
      });
      const paidOrApproved = await tx.estatePayoutRequest.findMany({
        where: { estateId, status: { in: ['approved', 'executing', 'paid'] } },
        select: { amount: true },
      });
      const committed = paidOrApproved.reduce((sum, row) => sum.add(row.amount), new Prisma.Decimal(0));
      const available = (collections._sum.amount ?? new Prisma.Decimal(0)).sub(committed);
      if (available.lt(amount)) throw new BadRequestException('Insufficient cleared estate funds.');

      const payout = await tx.estatePayoutRequest.create({ data: {
        estateId, beneficiaryId: beneficiary.id, amount, currency: CURRENCY,
        purpose: input.purpose, fundCategory: input.fundCategory ?? 'estate_operations',
        status: 'pending_approval', initiatedBy: actorUserId, idempotencyKeyHash: hash,
        policySnapshot: { threshold: policy!.threshold.toString(), requiredApprovals, requestHash },
      } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'payout.initiated',
        targetType: 'estate_payout_request', targetId: payout.id, outcome: 'success', occurredAt: new Date(),
        metadata: { amount: amount.toString(), beneficiaryId: beneficiary.id },
      } });
      return { ...payout, replayed: false };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async list(actorUserId: string, estateId: string) {
    await this.membership(actorUserId, estateId);
    return this.prisma.estatePayoutRequest.findMany({
      where: { estateId }, orderBy: { createdAt: 'desc' }, take: 100,
      include: { approvals: true, execution: true, beneficiary: { select: { displayName: true, bankName: true, accountNumber: true } } },
    });
  }

  async approve(actorUserId: string, payoutId: string, decision: 'approve' | 'reject', note: string) {
    const payout = await this.prisma.estatePayoutRequest.findUnique({ where: { id: payoutId } });
    if (!payout) throw new NotFoundException('Payout request not found.');
    const membership = await this.membership(actorUserId, payout.estateId);
    if (membership?.role !== ADMIN) throw new ForbiddenException('Only an authorized approver can decide payouts.');
    if (payout.initiatedBy === actorUserId) throw new ForbiddenException('Self-approval is not permitted.');
    if (payout.status !== 'pending_approval') throw new ConflictException('Payout is not awaiting approval.');

    await this.prisma.$transaction(async (tx) => {
      await tx.estatePayoutApproval.create({ data: {
        payoutId, approverId: actorUserId, decision, note: note || null,
      } });
      const approvals = await tx.estatePayoutApproval.findMany({ where: { payoutId } });
      const snapshot = payout.policySnapshot as { requiredApprovals?: number };
      const required = snapshot.requiredApprovals ?? 1;
      const approved = approvals.filter((row) => row.decision === 'approve');
      const rejected = approvals.some((row) => row.decision === 'reject');
      const status = rejected ? 'rejected' : approved.length >= required ? 'approved' : 'pending_approval';
      await tx.estatePayoutRequest.update({ where: { id: payoutId }, data: { status } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId: payout.estateId, action: `payout.${decision}d`,
        targetType: 'estate_payout_request', targetId: payoutId, outcome: 'success', occurredAt: new Date(),
        metadata: { note, status },
      } });
    });
    return { payoutId, decision };
  }

  async execute(actorUserId: string, payoutId: string, idempotencyKey: string | undefined) {
    const payout = await this.prisma.estatePayoutRequest.findUnique({
      where: { id: payoutId }, include: { beneficiary: true },
    });
    if (!payout) throw new NotFoundException('Payout request not found.');
    const membership = await this.membership(actorUserId, payout.estateId);
    if (membership?.role !== ADMIN) throw new ForbiddenException('Only the estate administrator can execute payouts.');
    if (payout.status !== 'approved') throw new ConflictException('Payout must be approved before execution.');
    const key = process.env.PAYSTACK_SECRET_KEY;
    if (!key) throw new ServiceUnavailableException('Paystack is not configured; payout execution is unavailable.');
    if (!idempotencyKey) throw new BadRequestException('An Idempotency-Key is required.');

    const response = await fetch('https://api.paystack.co/transfer', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', 'Idempotency-Key': idempotencyKey },
      body: JSON.stringify({
        source: 'balance',
        amount: payout.amount.times(100).toNumber(),
        recipient: payout.beneficiary!.accountNumber,
        reference: `PAYOUT-${payout.id}`,
        narration: payout.purpose,
      }),
    });
    const payload = await response.json().catch(() => ({}));
    const execution = await this.prisma.estatePayoutExecution.upsert({
      where: { payoutId },
      update: { status: response.ok ? 'executing' : 'failed', providerResponse: payload,
        providerReference: payload?.data?.reference ?? null, executedBy: actorUserId },
      create: { payoutId, provider: 'paystack', status: response.ok ? 'executing' : 'failed',
        providerResponse: payload, providerReference: payload?.data?.reference ?? null, executedBy: actorUserId },
    });
    await this.prisma.estatePayoutRequest.update({ where: { id: payoutId },
      data: { status: response.ok ? 'executing' : 'failed' } });
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'estate', estateId: payout.estateId, action: 'payout.executed',
      targetType: 'estate_payout_request', targetId: payoutId, outcome: response.ok ? 'success' : 'failure', occurredAt: new Date(),
    } });
    return execution;
  }
}
