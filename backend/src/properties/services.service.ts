import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { Prisma, type EstateRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { LedgerService } from './ledger.service.js';
import type { CreateEstateServiceDto, SetEstateServiceStatusDto } from './services.dto.js';

const MANAGEMENT_ROLES: EstateRole[] = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'FINANCE_MANAGER'];

@Injectable()
export class EstateServicesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  private hash(value: string) { return createHash('sha256').update(value, 'utf8').digest('hex'); }

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

  private view(row: any) {
    return {
      id: row.id, estateId: row.estateId, code: row.code, name: row.name,
      description: row.description, category: row.category, provider: row.provider,
      amount: row.amount.toString(), currency: row.currency,
      demo: row.demo, status: row.status.toLowerCase(),
      createdAt: row.createdAt.toISOString(),
    };
  }

  private orderView(row: any) {
    return {
      id: row.id, estateId: row.estateId, serviceId: row.serviceId, orderedBy: row.orderedBy,
      amount: row.amount.toString(), currency: row.currency, status: row.status.toLowerCase(),
      provider: row.provider, providerReference: row.providerReference,
      fulfilmentCode: row.fulfilmentCode, failureReason: row.failureReason,
      demo: row.provider.toUpperCase().startsWith('DEMO') || Boolean(row.fulfilmentCode?.startsWith('DEMO-')),
      paidAt: row.paidAt?.toISOString() ?? null, fulfilledAt: row.fulfilledAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
    };
  }

  async listDefinitions(actorUserId: string, estateId: string) {
    await this.membership(actorUserId, estateId);
    const rows = await this.prisma.estateServiceDefinition.findMany({
      where: { estateId }, orderBy: [{ category: 'asc' }, { code: 'asc' }], take: 200,
    });
    return { items: rows.map((row) => this.view(row)) };
  }

  async createDefinition(actorUserId: string, estateId: string, input: CreateEstateServiceDto) {
    await this.membership(actorUserId, estateId, true);
    try {
      const row = await this.prisma.estateServiceDefinition.create({ data: {
        estateId, code: input.code.trim().toUpperCase(), name: input.name.trim(),
        description: input.description?.trim() || null, category: input.category.trim().toLowerCase(),
        provider: input.provider.trim(), amount: input.amount, currency: input.currency,
        demo: true, status: 'ACTIVE', createdById: actorUserId,
      } });
      await this.prisma.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'estate_service.created',
        targetType: 'estate_service_definition', targetId: row.id, outcome: 'success', occurredAt: new Date(),
        metadata: { code: row.code, provider: row.provider, demo: true },
      } });
      return this.view(row);
    } catch (error) {
      if ((error as { code?: string })?.code === 'P2002') {
        throw new ConflictException('A service with this code already exists in the estate.');
      }
      throw error;
    }
  }

  async setStatus(actorUserId: string, estateId: string, serviceId: string, input: SetEstateServiceStatusDto) {
    await this.membership(actorUserId, estateId, true);
    const existing = await this.prisma.estateServiceDefinition.findFirst({ where: { id: serviceId, estateId }, select: { id: true } });
    if (!existing) throw new NotFoundException('Service not found in this estate.');
    const updated = await this.prisma.estateServiceDefinition.update({
      where: { id: serviceId }, data: { status: input.status },
    });
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'estate', estateId, action: 'estate_service.status_changed',
      targetType: 'estate_service_definition', targetId: serviceId, outcome: 'success', occurredAt: new Date(),
      metadata: { status: input.status },
    } });
    return this.view(updated);
  }

  async listOrders(actorUserId: string, estateId: string) {
    const membership = await this.membership(actorUserId, estateId);
    const isManager = MANAGEMENT_ROLES.includes(membership.role);
    const rows = await this.prisma.estateServiceOrder.findMany({
      where: { estateId, ...(isManager ? {} : { orderedBy: actorUserId }) },
      orderBy: { createdAt: 'desc' }, take: 200,
    });
    return { items: rows.map((row) => this.orderView(row)) };
  }

  async order(actorUserId: string, estateId: string, serviceId: string, idempotencyKey: string | undefined) {
    if (!idempotencyKey || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new BadRequestException('A valid Idempotency-Key is required.');
    }
    await this.membership(actorUserId, estateId);
    const keyHash = this.hash(`estate-service-order:v1:${idempotencyKey}`);
    const payloadHash = this.hash(JSON.stringify({ estateId, serviceId }));

    const replayed = await this.prisma.estateServiceOrder.findUnique({
      where: { estateId_orderedBy_idempotencyKeyHash: { estateId, orderedBy: actorUserId, idempotencyKeyHash: keyHash } },
    });
    if (replayed) {
      if (replayed.payloadHash !== payloadHash) {
        throw new ConflictException('This idempotency key was already used for a different service.');
      }
      return { ...this.orderView(replayed), replayed: true };
    }

    const service = await this.prisma.estateServiceDefinition.findFirst({
      where: { id: serviceId, estateId, status: 'ACTIVE' },
      select: { id: true, amount: true, currency: true, provider: true, name: true, demo: true },
    });
    if (!service) throw new NotFoundException('An active service was not found in this estate.');
    const wallet = await this.prisma.estateWallet.findUnique({
      where: { estateId_userId_currency: { estateId, userId: actorUserId, currency: service.currency } },
      select: { id: true, status: true },
    });
    if (!wallet || wallet.status !== 'active') {
      throw new BadRequestException('An active fund account is required to order services.');
    }

    try {
      return await this.prisma.$transaction(async (tx) => {
        const existing = await tx.estateServiceOrder.findUnique({
          where: { estateId_orderedBy_idempotencyKeyHash: { estateId, orderedBy: actorUserId, idempotencyKeyHash: keyHash } },
        });
        if (existing) return { ...this.orderView(existing), replayed: true };
        await tx.$queryRaw`SELECT id FROM estate_wallets WHERE id = ${wallet.id} FOR UPDATE`;
        const sums = await tx.estateWalletTransaction.groupBy({
          by: ['type'], where: { walletId: wallet.id, status: 'posted' }, _sum: { amount: true },
        });
        const credits = sums.find((row) => row.type === 'credit')?._sum?.amount ?? new Prisma.Decimal(0);
        const debits = sums.find((row) => row.type === 'debit')?._sum?.amount ?? new Prisma.Decimal(0);
        if (credits.sub(debits).lt(service.amount)) {
          throw new BadRequestException('Insufficient fund account balance for this service.');
        }
        const now = new Date();
        const reference = `SVC-${randomUUID().replace(/-/g, '').slice(0, 16).toUpperCase()}`;
        const journalId = await this.ledger.post(tx, {
          estateId, reference: `JRN-${reference}`, sourceType: 'service_order',
          sourceId: serviceId, description: `Demo service order: ${service.name}`,
          currency: service.currency,
          debitAccount: this.ledger.walletAccount(wallet.id),
          creditAccount: this.ledger.providerClearing(
            service.demo ? 'LANCON' : service.provider,
            service.currency,
          ),
          amount: service.amount, occurredAt: now,
        });
        await tx.estateWalletTransaction.create({ data: {
          walletId: wallet.id, estateId, type: 'debit', amount: service.amount,
          currency: service.currency, reference, description: `Service: ${service.name}`,
          sourceType: 'service_order', sourceId: serviceId, status: 'posted', journalId,
        } });
        const order = await tx.estateServiceOrder.create({ data: {
          estateId, serviceId, orderedBy: actorUserId, amount: service.amount,
          currency: service.currency, status: 'FULFILLED',
          provider: service.demo ? 'LANCON Services' : service.provider,
          providerReference: `DEMO-ORDER-${reference}`,
          fulfilmentCode: `LAN-${randomUUID().replace(/-/g, '').slice(0, 12).toUpperCase()}`,
          paidAt: now, fulfilledAt: now, idempotencyKeyHash: keyHash, payloadHash,
        } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'estate_service.ordered_demo',
          targetType: 'estate_service_order', targetId: order.id, outcome: 'success', occurredAt: now,
          metadata: { serviceId, amount: service.amount.toString(), journalId, demo: true },
        } });
        return { ...this.orderView(order), replayed: false };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (['P2002', 'P2034'].includes((error as { code?: string })?.code ?? '')) {
        const existing = await this.prisma.estateServiceOrder.findUnique({
          where: { estateId_orderedBy_idempotencyKeyHash: { estateId, orderedBy: actorUserId, idempotencyKeyHash: keyHash } },
        });
        if (existing) return { ...this.orderView(existing), replayed: true };
        throw new ConflictException('The service order changed during creation. Retry with the same idempotency key.');
      }
      throw error;
    }
  }
}

