import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateVisitorPassDto } from './visitor-passes.dto.js';

const { createVisitorPassUseCase, VisitorPassCreationUseCaseError } = require('../../modules/visitors/create-visitor-pass.js') as {
  createVisitorPassUseCase: (ports: Record<string, (...args: any[]) => any>) => (input: any) => Promise<any>;
  VisitorPassCreationUseCaseError: new (...args: any[]) => Error & { code: string };
};
const { createMyVisitorPassListUseCase } = require('../../modules/visitors/list-my-visitor-passes.js') as {
  createMyVisitorPassListUseCase: (ports: Record<string, (...args: any[]) => any>) => (input: any) => Promise<any>;
};
const { createVisitorPassRevocationUseCase, VisitorPassRevocationUseCaseError } = require('../../modules/visitors/revoke-visitor-pass.js') as {
  createVisitorPassRevocationUseCase: (ports: Record<string, (...args: any[]) => any>) => (input: any) => Promise<any>;
  VisitorPassRevocationUseCaseError: new (...args: any[]) => Error & { code: string };
};

@Injectable()
export class VisitorPassesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(actorUserId: string, input: CreateVisitorPassDto, idempotencyKey?: string) {
    const createPass = createVisitorPassUseCase({
      transaction: async (work: (tx: Prisma.TransactionClient) => Promise<unknown>) => {
        for (let attempt = 0; ; attempt += 1) {
          try { return await this.prisma.$transaction(work, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }); }
          catch (error) { if ((error as { code?: string })?.code !== 'P2034' || attempt >= 2) throw error; }
        }
      },
      resolveHostPropertyAccess: async (tx: Prisma.TransactionClient, scope: any) => {
        const today = new Date(`${new Date().toISOString().slice(0, 10)}T00:00:00.000Z`);
        const [residents, tenants, landlords] = await Promise.all([
          tx.propertyOccupancy.findMany({ where: { residentId: scope.actorUserId, estateId: scope.estateId, status: 'ACTIVE', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
          tx.estateTenancy.findMany({ where: { tenantUserId: scope.actorUserId, estateId: scope.estateId, status: 'ACTIVE', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
          tx.estateOwnershipInterest.findMany({ where: { ownerUserId: scope.actorUserId, estateId: scope.estateId, status: 'ACTIVE', verificationStatus: 'VERIFIED', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
        ]);
        const ids = [...new Set([...residents, ...tenants, ...landlords].map((record) => record.propertyId))];
        if (!scope.propertyId || !ids.includes(scope.propertyId)) return null;
        return { userId: scope.actorUserId, estateId: scope.estateId, propertyId: scope.propertyId, propertyIds: ids, active: true, mayCreateVisitorPass: true };
      },
      findPropertyForUpdate: async (tx: Prisma.TransactionClient, scope: any) => {
        await tx.$queryRaw`SELECT id FROM estate_properties WHERE id = ${scope.propertyId}::uuid AND estate_id = ${scope.estateId}::uuid FOR UPDATE`;
        const property = await tx.estateProperty.findFirst({ where: { id: scope.propertyId, estateId: scope.estateId }, select: { id: true, estateId: true, status: true } });
        return property ? { id: property.id, estateId: property.estateId, status: property.status === 'ARCHIVED' ? 'archived' : 'active' } : null;
      },
      getVisitorPassPolicy: async (_tx: Prisma.TransactionClient, _scope: any) => ({ maximumUses: 1, maximumDurationMs: 24 * 60 * 60 * 1000, collectVehicleDetails: true }),
      generatePassId: async () => randomUUID(),
      createPassRecord: async (tx: Prisma.TransactionClient, record: any) => tx.estateVisitorPass.create({ data: {
        id: record.id, estateId: record.estateId, propertyId: record.propertyId, hostUserId: record.hostUserId,
        visitorDisplayName: record.visitorDisplayName, credentialHash: record.credentialHash,
        validFrom: new Date(record.validFrom), validUntil: new Date(record.validUntil), allowedUses: record.allowedUses,
        useCount: record.useCount, revokedAt: record.revokedAt, vehicleSummary: record.vehicleSummary, createdAt: new Date(record.createdAt),
      } }),
      appendAuditEvent: async (tx: Prisma.TransactionClient, event: any) => tx.auditEvent.create({ data: {
        actorUserId: event.actorUserId, scope: event.scope, estateId: event.estateId, action: event.action,
        targetType: event.targetType, targetId: event.targetId, outcome: event.outcome, occurredAt: new Date(event.occurredAt),
      } }),
      enqueueHostNotice: async (tx: Prisma.TransactionClient, event: any) => tx.estateVisitorPassNoticeOutbox.create({ data: {
        estateId: event.estateId, passId: event.passId, eventType: 'visitor_pass.issued',
        payload: { estateId: event.estateId, passId: event.passId, hostUserId: event.hostUserId },
      } }),
      readVisitorPassCreationIdempotency: async (tx: Prisma.TransactionClient, scope: any) => tx.estateVisitorPassIdempotency.findUnique({ where: { actorUserId_estateId_idempotencyKeyHash: { actorUserId: scope.actorUserId, estateId: scope.estateId, idempotencyKeyHash: scope.idempotencyKeyHash } } }),
      claimVisitorPassCreationIdempotency: async (tx: Prisma.TransactionClient, scope: any) => tx.estateVisitorPassIdempotency.upsert({
        where: { actorUserId_estateId_idempotencyKeyHash: { actorUserId: scope.actorUserId, estateId: scope.estateId, idempotencyKeyHash: scope.idempotencyKeyHash } },
        create: { actorUserId: scope.actorUserId, estateId: scope.estateId, idempotencyKeyHash: scope.idempotencyKeyHash, payloadHash: scope.payloadHash, state: 'claimed' }, update: {},
      }),
      completeVisitorPassCreationIdempotency: async (tx: Prisma.TransactionClient, value: any) => tx.estateVisitorPassIdempotency.update({ where: { id: value.claim.id }, data: { payloadHash: value.payloadHash, state: 'completed', passId: value.passId } }),
    });
    try {
      const result = await createPass({ actorUserId, estateId: input.estateId, propertyId: input.propertyId,
        visitorDisplayName: input.visitorDisplayName, validFrom: input.validFrom, validUntil: input.validUntil,
        vehicleSummary: input.vehicleSummary?.trim() || null, idempotencyKey });
      return result;
    } catch (error) { this.throwDomainError(error); }
  }

  async listMine(actorUserId: string, estateId: string) {
    const list = createMyVisitorPassListUseCase({
      transaction: (work: (tx: Prisma.TransactionClient) => Promise<unknown>) => this.prisma.$transaction(work),
      resolveHostEstateAccess: async (tx: Prisma.TransactionClient, scope: any) => {
        const access = await this.resolvePropertyIds(tx, scope.actorUserId, scope.estateId);
        return access.length ? { userId: scope.actorUserId, estateId: scope.estateId, active: true } : null;
      },
      queryMyVisitorPasses: async (tx: Prisma.TransactionClient, scope: any) => tx.estateVisitorPass.findMany({
        where: { hostUserId: scope.actorUserId, estateId: scope.estateId }, orderBy: { createdAt: 'desc' }, take: scope.limit,
        select: { id: true, estateId: true, propertyId: true, hostUserId: true, visitorDisplayName: true, validFrom: true, validUntil: true, allowedUses: true, useCount: true, revokedAt: true, vehicleSummary: true, createdAt: true, property: { select: { code: true, unitNumber: true } } },
      }),
    });
    try { return await list({ actorUserId, estateId }); }
    catch (error) { this.throwDomainError(error); }
  }

  async listMyProperties(actorUserId: string, estateId: string) {
    const propertyIds = await this.resolvePropertyIds(this.prisma, actorUserId, estateId);
    if (!propertyIds.length) throw new ForbiddenException('An active resident, tenant or verified owner relationship is required.');
    const properties = await this.prisma.estateProperty.findMany({
      where: { estateId, id: { in: propertyIds }, status: { not: 'ARCHIVED' } },
      orderBy: { code: 'asc' }, take: 100,
      select: { id: true, code: true, unitNumber: true },
    });
    return { items: properties };
  }

  async createVisitorPass(actorUserId: string, input: CreateVisitorPassDto, idempotencyKey?: string) {
    return this.create(actorUserId, input, idempotencyKey);
  }

  async revoke(actorUserId: string, estateId: string, passId: string, reason: string) {
    const revoke = createVisitorPassRevocationUseCase({
      transaction: (work: (tx: Prisma.TransactionClient) => Promise<unknown>) => this.prisma.$transaction(work, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }),
      findHostPassForUpdate: async (tx: Prisma.TransactionClient, scope: any) => {
        await tx.$queryRaw`SELECT id FROM estate_visitor_passes WHERE id = ${scope.passId}::uuid AND estate_id = ${scope.estateId}::uuid AND host_user_id = ${scope.actorUserId}::uuid FOR UPDATE`;
        return tx.estateVisitorPass.findFirst({ where: { id: scope.passId, estateId: scope.estateId, hostUserId: scope.actorUserId }, select: { id: true, estateId: true, hostUserId: true, revokedAt: true } });
      },
      commitRevocation: async (tx: Prisma.TransactionClient, plan: any) => {
        const effect = plan.effects[0];
        return tx.estateVisitorPass.update({ where: { id: effect.passId }, data: { revokedAt: new Date(effect.revokedAt) }, select: { id: true, estateId: true, hostUserId: true, revokedAt: true } });
      },
      appendAuditEvent: async (tx: Prisma.TransactionClient, event: any) => tx.auditEvent.create({ data: {
        actorUserId: event.actorUserId, scope: event.scope, estateId: event.estateId, action: event.action,
        targetType: event.targetType, targetId: event.targetId, outcome: event.outcome,
        reason: event.reason, occurredAt: new Date(event.occurredAt),
      } }),
    });
    try { return await revoke({ actorUserId, estateId, passId, reason }); }
    catch (error) {
      if (error instanceof VisitorPassRevocationUseCaseError) {
        if (error.code === 'PASS_NOT_FOUND') throw new NotFoundException(error.message);
        if (error.code === 'ALREADY_REVOKED') throw new ConflictException(error.message);
        throw new BadRequestException(error.message);
      }
      throw error;
    }
  }

  private async resolvePropertyIds(tx: Prisma.TransactionClient, actorUserId: string, estateId: string) {
    const today = new Date(`${new Date().toISOString().slice(0, 10)}T00:00:00.000Z`);
    const [resident, tenant, landlord] = await Promise.all([
      tx.propertyOccupancy.findMany({ where: { residentId: actorUserId, estateId, status: 'ACTIVE', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
      tx.estateTenancy.findMany({ where: { tenantUserId: actorUserId, estateId, status: 'ACTIVE', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
      tx.estateOwnershipInterest.findMany({ where: { ownerUserId: actorUserId, estateId, status: 'ACTIVE', verificationStatus: 'VERIFIED', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
    ]);
    return [...new Set([...resident, ...tenant, ...landlord].map((item) => item.propertyId))];
  }

  private throwDomainError(error: unknown): never {
    const code = (error as { code?: string })?.code;
    if (error instanceof BadRequestException || error instanceof ForbiddenException || error instanceof NotFoundException || error instanceof ConflictException) throw error;
    if (error instanceof VisitorPassCreationUseCaseError) {
      if (code === 'HOST_ACCESS_DENIED') throw new ForbiddenException((error as Error).message);
      if (code === 'PROPERTY_NOT_FOUND') throw new NotFoundException((error as Error).message);
      if (code === 'VISITOR_PASS_ALREADY_CREATED' || code === 'IDEMPOTENCY_KEY_REUSED') throw new ConflictException((error as Error).message);
      throw new BadRequestException((error as Error).message);
    }
    if (code === 'P2002') throw new ConflictException('A visitor pass with this request key already exists.');
    throw error instanceof Error ? error : new Error('Visitor pass operation failed.');
  }
}
