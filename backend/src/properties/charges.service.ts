import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import type { Prisma as PrismaTypes } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateEstateChargeDto, CreateEstateChargeVersionDto, CreateEstateInvoiceDraftDto, CreateEstateSettlementPolicyDto, RecordEstateInvoiceSettlementDto } from './charges.dto.js';

const MANAGER_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER', 'FINANCE_MANAGER'] as const;

@Injectable()
export class EstateChargesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(actorUserId: string, estateId: string) {
    await this.requireAccess(actorUserId, estateId);
    const charges = await this.prisma.estateChargeDefinition.findMany({
      where: { estateId }, orderBy: [{ code: 'asc' }], take: 200,
      include: { versions: { orderBy: { versionNumber: 'desc' }, take: 30 } },
    });
    return { items: charges.map((charge) => ({
      id: charge.id, estateId, code: charge.code,
      versions: charge.versions.map((version) => this.toVersion(version)),
    })) };
  }

  async create(actorUserId: string, estateId: string, input: CreateEstateChargeDto) {
    this.validateDates(input);
    const code = input.code.trim().toUpperCase();
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireAccess(actorUserId, estateId, tx);
        await this.validateScope(tx, estateId, input);
        const now = new Date();
        const charge = await tx.estateChargeDefinition.create({ data: {
          estateId, code, createdById: actorUserId,
          versions: { create: this.versionData(input, actorUserId, 1) },
        }, include: { versions: true } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'estate_charge.created', targetType: 'estate_charge', targetId: charge.id,
          outcome: 'success', occurredAt: now, metadata: { code, initialVersionStatus: 'draft' },
        } });
        return { id: charge.id, estateId, code, version: this.toVersion(charge.versions[0]) };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string })?.code === 'P2002') throw new ConflictException('A charge with this code already exists in the estate.');
      throw error;
    }
  }

  async createVersion(actorUserId: string, estateId: string, chargeId: string, input: CreateEstateChargeVersionDto) {
    this.validateDates(input);
    try {
      return await this.prisma.$transaction(async (tx) => {
      await this.requireAccess(actorUserId, estateId, tx);
      await this.validateScope(tx, estateId, input);
      const charge = await tx.estateChargeDefinition.findFirst({ where: { id: chargeId, estateId }, select: { id: true } });
      if (!charge) throw new NotFoundException('Estate charge not found.');
      const latest = await tx.estateChargeVersion.findFirst({ where: { chargeId }, orderBy: { versionNumber: 'desc' }, select: { versionNumber: true } });
      const versionNumber = (latest?.versionNumber ?? 0) + 1;
      const version = await tx.estateChargeVersion.create({ data: { chargeId, ...this.versionData(input, actorUserId, versionNumber) } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'estate_charge.version_created', targetType: 'estate_charge_version', targetId: version.id,
        outcome: 'success', occurredAt: new Date(), metadata: { chargeId, versionNumber },
      } });
      return { id: chargeId, estateId, code: undefined, version: this.toVersion(version) };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (['P2002', 'P2034'].includes((error as { code?: string })?.code ?? '')) throw new ConflictException('Another charge version was saved at the same time. Reload and try again.');
      throw error;
    }
  }

  async activateVersion(actorUserId: string, estateId: string, chargeId: string, versionId: string) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireAccess(actorUserId, estateId, tx);
        const charge = await tx.estateChargeDefinition.findFirst({ where: { id: chargeId, estateId }, select: { id: true, code: true } });
        const version = await tx.estateChargeVersion.findFirst({ where: { id: versionId, chargeId, status: 'DRAFT' } });
        if (!charge || !version) throw new NotFoundException('Draft charge version not found.');
        if (version.propertyId) {
          const property = await tx.estateProperty.findFirst({ where: { id: version.propertyId, estateId, status: { not: 'ARCHIVED' } }, select: { id: true } });
          if (!property) throw new ConflictException('The charge property is no longer active in this estate.');
        }
        const start = this.dateOnly(version.effectiveFrom);
        const today = this.businessToday();
        if (start < today) throw new BadRequestException('A charge version cannot be activated retroactively.');
        if (version.effectiveTo && this.dateOnly(version.effectiveTo) < start) throw new BadRequestException('The effective end date must be on or after the start date.');

        const overlap = await tx.estateChargeVersion.findMany({
          where: { chargeId, status: 'ACTIVE', effectiveFrom: { lte: version.effectiveTo ?? new Date('9999-12-31T00:00:00.000Z') }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: version.effectiveFrom } }] },
          orderBy: { effectiveFrom: 'asc' },
        });
        for (const previous of overlap) {
          if (this.dateOnly(previous.effectiveFrom) >= start) throw new ConflictException('This version overlaps a later active version. Choose a later effective date or retire the conflicting version first.');
          const dayBefore = new Date(`${start}T00:00:00.000Z`);
          dayBefore.setUTCDate(dayBefore.getUTCDate() - 1);
          await tx.estateChargeVersion.update({ where: { id: previous.id }, data: { effectiveTo: dayBefore } });
        }
        const activatedAt = new Date();
        const activated = await tx.estateChargeVersion.update({ where: { id: version.id }, data: { status: 'ACTIVE', activatedById: actorUserId, activatedAt } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'estate_charge.version_activated', targetType: 'estate_charge_version', targetId: version.id,
          outcome: 'success', occurredAt: activatedAt, metadata: { chargeId, code: charge.code, versionNumber: version.versionNumber, effectiveFrom: start },
        } });
        return { chargeId, estateId, version: this.toVersion(activated) };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string })?.code === 'P2034') throw new ConflictException('Another charge change was saved at the same time. Reload and try again.');
      throw error;
    }
  }

  async createInvoiceDraft(actorUserId: string, estateId: string, input: CreateEstateInvoiceDraftDto, idempotencyKey: string | undefined) {
    if (!idempotencyKey || idempotencyKey.length < 8 || idempotencyKey.length > 128) throw new BadRequestException('A valid Idempotency-Key header is required.');
    this.validateDatePair(input.periodStart, input.periodEnd);
    const payerEmail = input.payerEmail.trim().toLowerCase();
    const keyHash = this.hash(`estate-invoice-draft:v1:${idempotencyKey}`);
    const payloadHash = this.hash(JSON.stringify({
      chargeVersionId: input.chargeVersionId, propertyId: input.propertyId, payerEmail,
      periodStart: input.periodStart, periodEnd: input.periodEnd,
    }));
    const replay = (record: any, replayed = true) => ({
      id: record.id, estateId, invoiceNumber: record.invoiceNumber, status: record.status.toLowerCase(),
      currency: record.currency, subtotal: record.subtotal.toString(), total: record.total.toString(),
      periodStart: this.dateOnly(record.periodStart), periodEnd: this.dateOnly(record.periodEnd), dueDate: this.dateOnly(record.dueDate), replayed,
    });
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireAccess(actorUserId, estateId, tx);
        const prior = await tx.estateInvoiceDraft.findUnique({
          where: { createdById_estateId_idempotencyKeyHash: { createdById: actorUserId, estateId, idempotencyKeyHash: keyHash } },
        });
        if (prior) {
          if (prior.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was already used for different invoice details.');
          return replay(prior);
        }

        const version = await tx.estateChargeVersion.findFirst({
          where: { id: input.chargeVersionId, status: 'ACTIVE', charge: { estateId } },
          include: { charge: { select: { code: true } } },
        });
        if (!version) throw new NotFoundException('An active charge version was not found in this estate.');
        const start = this.date(input.periodStart);
        const end = this.date(input.periodEnd);
        this.validateBillingPeriod(version.recurrence, input.periodStart, input.periodEnd);
        if (input.periodStart < this.dateOnly(version.effectiveFrom) || (version.effectiveTo && input.periodEnd > this.dateOnly(version.effectiveTo))) {
          throw new BadRequestException('The entire billing period must fall within the active charge version dates.');
        }
        const property = await tx.estateProperty.findFirst({
          where: { id: input.propertyId, estateId, status: { not: 'ARCHIVED' } },
          select: { id: true, code: true, propertyType: true, status: true },
        });
        if (!property) throw new NotFoundException('An active property was not found in this estate.');
        if (version.appliesTo === 'PROPERTY' && version.propertyId !== property.id) throw new BadRequestException('The selected property does not match this charge scope.');
        if (version.appliesTo === 'PROPERTY_TYPE' && version.propertyType?.toLowerCase() !== property.propertyType.toLowerCase()) throw new BadRequestException('The property type does not match this charge scope.');
        if (version.appliesTo === 'ESTATE' && version.propertyId) throw new BadRequestException('The estate-wide charge has an invalid property scope.');

        const payer = await tx.user.findFirst({ where: { emailNormalized: payerEmail, status: 'ACTIVE' }, select: { id: true } });
        if (!payer) throw new NotFoundException('An active account with that email address was not found.');

        const relationshipWindow = {
          effectiveFrom: { lte: end },
          OR: [{ effectiveTo: null }, { effectiveTo: { gte: start } }],
        };
        const [occupancy, tenancy, ownership] = await Promise.all([
          tx.propertyOccupancy.findFirst({ where: { estateId, propertyId: property.id, residentId: payer.id, status: 'ACTIVE', ...relationshipWindow }, select: { id: true } }),
          tx.estateTenancy.findFirst({ where: { estateId, propertyId: property.id, tenantUserId: payer.id, status: 'ACTIVE', ...relationshipWindow }, select: { id: true } }),
          tx.estateOwnershipInterest.findFirst({ where: { estateId, propertyId: property.id, ownerUserId: payer.id, status: 'ACTIVE', verificationStatus: 'VERIFIED', ...relationshipWindow }, select: { id: true } }),
        ]);
        if (!occupancy && !tenancy && !ownership) throw new ForbiddenException('The payer must have an approved relationship with this property during the billing period.');

        const periodDays = (end.getTime() - start.getTime()) / 86400000 + 1;
        const dueDate = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), Math.min(version.dueDay, new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 0)).getUTCDate())));
        const lineSnapshot = [{
          chargeCode: version.charge.code, chargeVersion: version.versionNumber, description: version.name,
          category: version.category, amount: version.amount.toString(), currency: version.currency,
          quantity: '1', periodStart: input.periodStart, periodEnd: input.periodEnd, periodDays,
        }];
        const invoiceId = randomUUID();
        const invoiceNumber = `DRAFT-${invoiceId.replaceAll('-', '').slice(0, 12).toUpperCase()}`;
        const amount = version.amount;
        const created = await tx.estateInvoiceDraft.create({ data: {
          id: invoiceId, estateId, invoiceNumber, chargeVersionId: version.id, propertyId: property.id,
          payerUserId: payer.id, createdById: actorUserId, periodStart: start, periodEnd: end, dueDate,
          currency: version.currency, subtotal: amount, total: amount, lineSnapshot: lineSnapshot as Prisma.InputJsonValue,
          idempotencyKeyHash: keyHash, payloadHash,
        } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'estate_invoice.draft_created', targetType: 'estate_invoice_draft', targetId: created.id,
          outcome: 'success', occurredAt: created.createdAt, metadata: { invoiceNumber, propertyId: property.id, payerUserId: payer.id, chargeVersionId: version.id, periodStart: input.periodStart, periodEnd: input.periodEnd },
        } });
        return replay(created, false);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      const code = (error as { code?: string })?.code;
      if (code === 'P2002') {
        const existing = await this.prisma.estateInvoiceDraft.findUnique({ where: { createdById_estateId_idempotencyKeyHash: { createdById: actorUserId, estateId, idempotencyKeyHash: keyHash } } });
        if (existing) {
          if (existing.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was already used for different invoice details.');
          return replay(existing);
        }
        throw new ConflictException('An invoice draft already exists for this payer, property, charge version and billing period.');
      }
      if (code === 'P2034') throw new ConflictException('The invoice draft changed during creation. Retry with the same idempotency key.');
      throw error;
    }
  }

  async listInvoiceDrafts(actorUserId: string, estateId: string) {
    await this.requireAccess(actorUserId, estateId);
    const rows = await this.prisma.estateInvoiceDraft.findMany({
      where: { estateId }, orderBy: [{ createdAt: 'desc' }], take: 100,
      include: { property: { select: { code: true } }, payer: { select: { displayName: true } }, chargeVersion: { include: { charge: { select: { code: true } } } }, settlements: { orderBy: { receivedAt: 'desc' }, take: 20 } },
    });
    const settlementTotals = rows.length ? await this.prisma.estateInvoiceSettlement.groupBy({
      by: ['invoiceId'], where: { estateId, invoiceId: { in: rows.map((row) => row.id) } }, _sum: { amount: true },
    }) : [];
    const paidByInvoice = new Map(settlementTotals.map((item) => [item.invoiceId, item._sum.amount ?? new Prisma.Decimal(0)]));
    return { items: rows.map((row) => ({
      id: row.id, invoiceNumber: row.invoiceNumber, status: row.status.toLowerCase(),
      chargeCode: row.chargeVersion.charge.code, description: row.chargeVersion.name,
      propertyCode: row.property.code, payerName: row.payer.displayName,
      currency: row.currency, total: row.total.toFixed(2),
      balance: row.total.minus(paidByInvoice.get(row.id) ?? new Prisma.Decimal(0)).toFixed(2),
      settlements: row.settlements.map((item) => ({ amount: item.amount.toFixed(2), receivedAt: item.receivedAt.toISOString(), receiptNumber: item.receiptNumber })),
      periodStart: this.dateOnly(row.periodStart), periodEnd: this.dateOnly(row.periodEnd), dueDate: this.dateOnly(row.dueDate),
      createdAt: row.createdAt.toISOString(),
    })) };
  }

  async recordInvoiceSettlement(actorUserId: string, estateId: string, invoiceId: string, input: RecordEstateInvoiceSettlementDto) {
    const bankReference = input.bankReference.trim();
    const normalizedBankReference = bankReference.replace(/\s+/g, '').toUpperCase();
    const receivedAt = new Date(input.receivedAt);
    const note = input.verificationNote.trim();
    if (!normalizedBankReference) throw new BadRequestException('Enter the bank transfer reference.');
    if (!Number.isFinite(receivedAt.valueOf()) || receivedAt > new Date()) throw new BadRequestException('The bank transfer date cannot be in the future.');
    const settlementId = randomUUID();
    const receiptNumber = `RCP-${settlementId.replaceAll('-', '').slice(0, 18).toUpperCase()}`;
    try {
      return await this.prisma.$transaction(async (tx) => {
        const membership = await tx.estateMembership.findFirst({ where: {
          userId: actorUserId, estateId, status: 'ACTIVE', role: { in: ['ESTATE_ADMINISTRATOR', 'FINANCE_MANAGER'] }, estate: { status: 'ACTIVE' },
        }, select: { id: true } });
        if (!membership) throw new ForbiddenException('Active estate finance or administrator access is required to reconcile bank transfers.');

        const duplicate = await tx.estateInvoiceSettlement.findFirst({ where: { estateId, normalizedBankReference } });
        if (duplicate) {
          if (duplicate.invoiceId !== invoiceId || duplicate.amount.toFixed(2) !== input.amount) {
            throw new ConflictException('This bank reference has already been recorded against another settlement.');
          }
          return { id: duplicate.id, invoiceId, amount: duplicate.amount.toFixed(2), currency: duplicate.currency, receiptNumber: duplicate.receiptNumber, receivedAt: duplicate.receivedAt.toISOString(), replayed: true };
        }

        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_invoice_drafts WHERE id = ${invoiceId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const invoice = await tx.estateInvoiceDraft.findFirst({ where: { id: invoiceId, estateId }, select: { id: true, invoiceNumber: true, currency: true, total: true, status: true } });
        if (!invoice) throw new NotFoundException('Invoice not found in this estate.');
        if (!['ISSUED', 'PARTIALLY_PAID'].includes(invoice.status)) throw new ConflictException('Only an issued invoice with a balance can receive a settlement.');
        const amount = new Prisma.Decimal(input.amount);
        const settled = await tx.estateInvoiceSettlement.aggregate({ where: { estateId, invoiceId }, _sum: { amount: true } });
        const paidToDate = settled._sum.amount ?? new Prisma.Decimal(0);
        const balance = invoice.total.minus(paidToDate);
        if (balance.lte(0)) throw new ConflictException('This invoice has no outstanding balance.');
        if (amount.gt(balance)) throw new BadRequestException(`Settlement exceeds the outstanding balance of ${invoice.currency} ${balance.toFixed(2)}.`);
        const settlement = await tx.estateInvoiceSettlement.create({ data: {
          id: settlementId, estateId, invoiceId, verifiedById: actorUserId, amount, currency: invoice.currency,
          bankReference, normalizedBankReference, receiptNumber, receivedAt, verificationNote: note,
        } });
        const nextStatus = paidToDate.plus(amount).equals(invoice.total) ? 'PAID' : 'PARTIALLY_PAID';
        await tx.estateInvoiceDraft.update({ where: { id: invoice.id }, data: { status: nextStatus } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'estate_invoice.bank_transfer_reconciled', targetType: 'estate_invoice_settlement', targetId: settlement.id,
          outcome: 'success', occurredAt: new Date(), metadata: { invoiceId, invoiceNumber: invoice.invoiceNumber, amount: amount.toFixed(2), currency: invoice.currency, receiptNumber },
        } });
        return { id: settlement.id, invoiceId, amount: settlement.amount.toFixed(2), currency: settlement.currency, receiptNumber, receivedAt: settlement.receivedAt.toISOString(), replayed: false };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      const code = (error as { code?: string })?.code;
      if (code === 'P2034') throw new ConflictException('The invoice balance changed during reconciliation. Reload the invoice and try again.');
      if (code === 'P2002') throw new ConflictException('This bank reference or receipt was recorded concurrently. Reload settlements and check the receipt before retrying.');
      throw error;
    }
  }

  async listSettlementPolicies(actorUserId: string, estateId: string) {
    await this.requireAccess(actorUserId, estateId);
    const items = await this.prisma.estateSettlementPolicy.findMany({ where: { estateId }, orderBy: [{ currency: 'asc' }, { createdAt: 'desc' }], take: 100 });
    return { items: items.map((item) => this.settlementPolicyView(item)) };
  }

  async createSettlementPolicy(actorUserId: string, estateId: string, input: CreateEstateSettlementPolicyDto) {
    return this.prisma.$transaction(async (tx) => {
      await this.requireAccess(actorUserId, estateId, tx);
      const policy = await tx.estateSettlementPolicy.create({ data: {
        estateId, currency: input.currency.toUpperCase(), bankName: input.bankName.trim(), accountName: input.accountName.trim(),
        accountNumber: input.accountNumber.replace(/[ -]/g, ''), paymentReferenceFormat: input.paymentReferenceFormat.trim(), createdById: actorUserId,
      } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'estate_settlement_policy.created', targetType: 'estate_settlement_policy', targetId: policy.id,
        outcome: 'success', occurredAt: policy.createdAt, metadata: { currency: policy.currency, bankName: policy.bankName, status: 'draft' },
      } });
      return this.settlementPolicyView(policy);
    });
  }

  async activateSettlementPolicy(actorUserId: string, estateId: string, policyId: string) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estates WHERE id = ${estateId}::uuid FOR UPDATE`;
        await this.requireAccess(actorUserId, estateId, tx);
        const policy = await tx.estateSettlementPolicy.findFirst({ where: { id: policyId, estateId }, select: { id: true, currency: true, status: true } });
        if (!policy) throw new NotFoundException('Settlement instructions not found in this estate.');
        if (policy.status !== 'DRAFT') throw new ConflictException('Only draft settlement instructions can be activated. Create a new draft to change bank details.');
        await tx.estateSettlementPolicy.updateMany({ where: { estateId, currency: policy.currency, status: 'ACTIVE' }, data: { status: 'RETIRED' } });
        const active = await tx.estateSettlementPolicy.update({ where: { id: policy.id }, data: { status: 'ACTIVE' } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'estate_settlement_policy.activated', targetType: 'estate_settlement_policy', targetId: policy.id,
          outcome: 'success', occurredAt: new Date(), metadata: { currency: policy.currency },
        } });
        return this.settlementPolicyView(active);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (['P2002', 'P2034'].includes((error as { code?: string })?.code ?? '')) throw new ConflictException('Settlement instructions changed concurrently. Reload and try again.');
      throw error;
    }
  }

  async issueInvoiceDraft(actorUserId: string, estateId: string, invoiceDraftId: string) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireAccess(actorUserId, estateId, tx);
        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_invoice_drafts WHERE id = ${invoiceDraftId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const draft = await tx.estateInvoiceDraft.findFirst({ where: { id: invoiceDraftId, estateId }, include: { chargeVersion: { select: { category: true } } } });
        if (!draft) throw new NotFoundException('Invoice draft not found in this estate.');
        if (draft.status !== 'DRAFT') throw new ConflictException('Only an invoice draft can be issued.');
        const policy = await tx.estateSettlementPolicy.findFirst({ where: { estateId, currency: draft.currency, status: 'ACTIVE' } });
        if (!policy) throw new ConflictException(`Activate ${draft.currency} bank transfer instructions before issuing this invoice.`);
        const invoiceNumber = `INV-${draft.id.replaceAll('-', '').slice(0, 16).toUpperCase()}`;
        const settlementSnapshot = {
          method: 'bank_transfer', bankName: policy.bankName, accountName: policy.accountName,
          accountNumber: policy.accountNumber, currency: policy.currency,
          paymentReference: policy.paymentReferenceFormat.replaceAll('{{invoiceNumber}}', invoiceNumber),
        };
        const issuedAt = new Date();
        const issued = await tx.estateInvoiceDraft.updateMany({
          where: { id: draft.id, estateId, status: 'DRAFT' },
          data: { invoiceNumber, status: 'ISSUED', settlementPolicyId: policy.id, settlementSnapshot, issuedAt },
        });
        if (issued.count !== 1) throw new ConflictException('Invoice draft changed before it could be issued. Reload and try again.');
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'estate_invoice.issued', targetType: 'estate_invoice_draft', targetId: draft.id,
          outcome: 'success', occurredAt: issuedAt, metadata: { invoiceNumber, currency: draft.currency, total: draft.total.toFixed(2), settlementPolicyId: policy.id },
        } });
        return { id: draft.id, estateId, invoiceNumber, status: 'issued', currency: draft.currency, total: draft.total.toFixed(2), dueDate: this.dateOnly(draft.dueDate), issuedAt: issuedAt.toISOString(), settlement: settlementSnapshot };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string })?.code === 'P2034') throw new ConflictException('Invoice changed while issuing. Reload and try again.');
      throw error;
    }
  }

  private settlementPolicyView(policy: { id: string; estateId: string; currency: string; bankName: string; accountName: string; accountNumber: string; paymentReferenceFormat: string; status: string; createdAt: Date }) {
    return { id: policy.id, estateId: policy.estateId, currency: policy.currency, bankName: policy.bankName, accountName: policy.accountName, accountNumber: policy.accountNumber, paymentReferenceFormat: policy.paymentReferenceFormat, status: policy.status.toLowerCase(), createdAt: policy.createdAt.toISOString() };
  }

  async listMyInvoices(actorUserId: string) {
    const today = new Date(`${this.businessToday()}T00:00:00.000Z`);
    const relationship: PrismaTypes.EstateInvoiceDraftWhereInput = {
      OR: [
        { payerUserId: actorUserId },
        { property: { is: { occupancies: { some: { residentId: actorUserId, status: 'ACTIVE', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }] } } } } },
        { property: { is: { ownershipInterests: { some: { ownerUserId: actorUserId, status: 'ACTIVE', verificationStatus: 'VERIFIED', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }] } } } } },
        { property: { is: { tenancies: { some: { tenantUserId: actorUserId, status: 'ACTIVE', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }] } } } } },
      ],
    };
    const rows = await this.prisma.estateInvoiceDraft.findMany({
      where: { status: { in: ['ISSUED', 'PARTIALLY_PAID', 'PAID'] }, estate: { is: { status: 'ACTIVE' } }, property: { is: { status: { not: 'ARCHIVED' }, estate: { is: { memberships: { some: { userId: actorUserId, status: 'ACTIVE', role: { in: ['RESIDENT', 'LANDLORD'] } } } } } } }, AND: [relationship] },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'desc' }], take: 100,
      include: { estate: { select: { id: true, name: true } }, property: { select: { id: true, code: true } }, chargeVersion: { include: { charge: { select: { code: true } } } }, settlements: { orderBy: { receivedAt: 'asc' } } },
    });
    return { items: rows.map((row) => ({
      id: row.id, estateId: row.estate.id, estateName: row.estate.name, propertyId: row.property.id,
      invoiceNumber: row.invoiceNumber, category: row.chargeVersion.category, description: row.chargeVersion.name,
      propertyCode: row.property.code, currency: row.currency, total: row.total.toFixed(2),
      balance: row.total.minus(row.settlements.reduce((sum, item) => sum.plus(item.amount), new Prisma.Decimal(0))).toFixed(2),
      status: row.status === 'PAID' ? 'paid' : (row.status === 'PARTIALLY_PAID' ? 'partially_paid' : (this.dateOnly(row.dueDate) < this.businessToday() ? 'overdue' : 'due')), issuedAt: row.issuedAt?.toISOString() ?? row.createdAt.toISOString(), dueDate: this.dateOnly(row.dueDate),
      settlement: row.settlementSnapshot,
      periodStart: this.dateOnly(row.periodStart), periodEnd: this.dateOnly(row.periodEnd),
      lines: (Array.isArray(row.lineSnapshot) ? row.lineSnapshot : []).map((line: any) => ({ description: String(line.description ?? ''), amount: String(line.amount ?? '0.00') })),
      verifiedPayments: row.settlements.map((item) => ({ amount: item.amount.toFixed(2), currency: item.currency, receivedAt: item.receivedAt.toISOString(), receiptNumber: item.receiptNumber })),
    })) };
  }

  private date(value: string) { return new Date(`${value}T00:00:00.000Z`); }

  private validateDatePair(startValue: string, endValue: string) {
    const start = this.date(startValue); const end = this.date(endValue);
    if (start.toISOString().slice(0, 10) !== startValue || end.toISOString().slice(0, 10) !== endValue || end < start) throw new BadRequestException('Provide a valid billing period with an end date on or after the start date.');
  }

  private validateBillingPeriod(recurrence: string, start: string, end: string) {
    const from = this.date(start); const to = this.date(end);
    const lastDay = new Date(Date.UTC(to.getUTCFullYear(), to.getUTCMonth() + 1, 0)).getUTCDate();
    let valid = false;
    if (recurrence === 'ONE_TIME') valid = start === end;
    if (recurrence === 'MONTHLY') valid = from.getUTCDate() === 1 && from.getUTCFullYear() === to.getUTCFullYear() && from.getUTCMonth() === to.getUTCMonth() && to.getUTCDate() === lastDay;
    if (recurrence === 'QUARTERLY') valid = [0, 3, 6, 9].includes(from.getUTCMonth()) && from.getUTCDate() === 1 && to.getUTCFullYear() === from.getUTCFullYear() && to.getUTCMonth() === from.getUTCMonth() + 2 && to.getUTCDate() === lastDay;
    if (recurrence === 'ANNUALLY') valid = from.getUTCMonth() === 0 && from.getUTCDate() === 1 && to.getUTCFullYear() === from.getUTCFullYear() && to.getUTCMonth() === 11 && to.getUTCDate() === 31;
    if (!valid) throw new BadRequestException('Billing dates must match the charge recurrence period.');
  }

  private hash(value: string) { return createHash('sha256').update(value, 'utf8').digest('hex'); }

  private async requireAccess(actorUserId: string, estateId: string, tx: Prisma.TransactionClient | PrismaService = this.prisma) {
    const membership = await tx.estateMembership.findFirst({ where: {
      userId: actorUserId, estateId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES] }, estate: { status: 'ACTIVE' },
    }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate charge management access is required.');
    return { estateId, actorUserId };
  }

  private versionData(input: CreateEstateChargeDto | CreateEstateChargeVersionDto, actorUserId: string, versionNumber: number) {
    return {
      versionNumber, name: input.name.trim(), description: input.description?.trim() || null,
      category: input.category.trim().toLowerCase(), amount: input.amount, currency: input.currency,
      recurrence: input.recurrence, effectiveFrom: new Date(`${input.effectiveFrom}T00:00:00.000Z`),
      effectiveTo: input.effectiveTo ? new Date(`${input.effectiveTo}T00:00:00.000Z`) : null,
      dueDay: input.dueDay, graceDays: input.graceDays ?? 0, appliesTo: input.appliesTo,
      propertyId: input.appliesTo === 'PROPERTY' ? input.propertyId : null,
      propertyType: input.appliesTo === 'PROPERTY_TYPE' ? input.propertyType!.trim() : null,
      status: 'DRAFT' as const, createdById: actorUserId,
    };
  }

  private async validateScope(tx: Prisma.TransactionClient, estateId: string, input: CreateEstateChargeDto | CreateEstateChargeVersionDto) {
    if (input.appliesTo === 'PROPERTY') {
      if (!input.propertyId) throw new BadRequestException('Select a property for this charge scope.');
      const property = await tx.estateProperty.findFirst({ where: { id: input.propertyId, estateId, status: { not: 'ARCHIVED' } }, select: { id: true } });
      if (!property) throw new BadRequestException('The selected property is not active in this estate.');
    } else if (input.propertyId) {
      throw new BadRequestException('Property ID is only allowed for a single-property charge.');
    }
    if (input.appliesTo === 'PROPERTY_TYPE' && !input.propertyType?.trim()) throw new BadRequestException('Property type is required for this charge scope.');
    if (input.appliesTo !== 'PROPERTY_TYPE' && input.propertyType?.trim()) throw new BadRequestException('Property type must only be set for property-type charges.');
  }

  private validateDates(input: CreateEstateChargeDto) {
    const valid = (value: string) => {
      const parsed = new Date(`${value}T00:00:00.000Z`);
      return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value;
    };
    if (!valid(input.effectiveFrom) || (input.effectiveTo && !valid(input.effectiveTo))) throw new BadRequestException('Provide real calendar dates in YYYY-MM-DD format.');
    if (input.effectiveTo && input.effectiveTo < input.effectiveFrom) throw new BadRequestException('The effective end date must be on or after the start date.');
  }

  private dateOnly(value: Date) { return value.toISOString().slice(0, 10); }

  private businessToday() {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Lagos', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date());
    const part = (type: string) => parts.find((item) => item.type === type)?.value ?? '';
    return `${part('year')}-${part('month')}-${part('day')}`;
  }

  private toVersion(version: any) {
    return {
      id: version.id, versionNumber: version.versionNumber, name: version.name, description: version.description,
      category: version.category, amount: version.amount.toString(), currency: version.currency,
      recurrence: version.recurrence.toLowerCase(), effectiveFrom: this.dateOnly(version.effectiveFrom),
      effectiveTo: version.effectiveTo ? this.dateOnly(version.effectiveTo) : null,
      dueDay: version.dueDay, graceDays: version.graceDays, appliesTo: version.appliesTo.toLowerCase(),
      propertyId: version.propertyId, propertyType: version.propertyType, status: version.status.toLowerCase(),
      activatedAt: version.activatedAt?.toISOString() ?? null,
    };
  }
}
