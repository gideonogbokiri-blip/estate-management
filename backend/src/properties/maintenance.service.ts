import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateMaintenanceRequestDto, MaintenanceQueueQueryDto, ReviewMaintenanceRequestDto } from './maintenance.dto.js';

const { createMaintenanceRequestUseCase } = require('../../modules/operations/create-maintenance-request.js') as {
  createMaintenanceRequestUseCase: (ports: Record<string, (...args: any[]) => any>) => (input: any) => Promise<any>;
};
const { MaintenanceCommand, planMaintenanceTransition, planMaintenanceUpdate } = require('../../modules/operations/maintenance.js') as {
  MaintenanceCommand: Record<string, string>;
  planMaintenanceTransition: (request: any, input: any) => any;
  planMaintenanceUpdate: (request: any, input: any) => any;
};

const MANAGER_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER'] as const;
const STATUS_TO_DB: Record<string, string> = {
  submitted: 'SUBMITTED', under_review: 'UNDER_REVIEW', assigned: 'ASSIGNED',
  in_progress: 'IN_PROGRESS', awaiting_parts: 'AWAITING_PARTS', resolved: 'RESOLVED',
  closed: 'CLOSED', rejected: 'REJECTED', reopened: 'REOPENED',
};
const currentDate = () => new Date(`${new Date().toISOString().slice(0, 10)}T00:00:00.000Z`);

@Injectable()
export class MaintenanceService {
  constructor(private readonly prisma: PrismaService) {}

  async create(actorUserId: string, input: CreateMaintenanceRequestDto, idempotencyKey: string | undefined) {
    if (!idempotencyKey) throw new BadRequestException('An Idempotency-Key header is required to submit a maintenance request.');
    const submit = createMaintenanceRequestUseCase({
      transaction: async (work: (tx: Prisma.TransactionClient) => Promise<unknown>) => {
        for (let attempt = 0; ; attempt += 1) {
          try {
            return await this.prisma.$transaction((tx) => work(tx), { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
          } catch (error) {
            if ((error as { code?: string })?.code !== 'P2034' || attempt >= 2) throw error;
          }
        }
      },
      resolveResidentPropertyAccess: async (tx: Prisma.TransactionClient, scope: { actorUserId: string; estateId: string; propertyId: string | null }) => {
        const access = await this.resolvePropertyAccess(tx, scope.actorUserId, scope.estateId);
        if (!access || !scope.propertyId || !access.propertyIds.includes(scope.propertyId)) return null;
        return { userId: scope.actorUserId, estateId: scope.estateId, propertyId: scope.propertyId, active: true, maySubmitMaintenance: true };
      },
      findPropertyForUpdate: async (tx: Prisma.TransactionClient, scope: { estateId: string; propertyId: string }) => tx.estateProperty.findFirst({
        where: { id: scope.propertyId, estateId: scope.estateId }, select: { id: true, estateId: true, status: true },
      }),
      getMaintenancePolicy: async () => ({ allowedCategories: ['plumbing', 'electrical', 'security', 'cleaning', 'other'], allowedPriorities: ['normal', 'high', 'urgent'] }),
      verifyAttachments: async (_tx: Prisma.TransactionClient, value: { attachmentIds: string[] }) => value.attachmentIds.length === 0,
      generateRequestId: async () => randomUUID(),
      createRequestRecord: async (tx: Prisma.TransactionClient, record: any) => {
        const reference = `MNT-${record.id.replaceAll('-', '').slice(0, 10).toUpperCase()}`;
        const created = await tx.estateMaintenanceRequest.create({ data: {
          id: record.id, estateId: record.estateId, propertyId: record.propertyId, requesterUserId: record.requesterUserId,
          reference, category: record.category, priority: record.priority, description: record.description,
          status: 'SUBMITTED', submittedAt: new Date(record.submittedAt),
        } });
        await tx.estateMaintenanceHistory.create({ data: {
          requestId: created.id, actorUserId: actorUserId, fromStatus: null, toStatus: 'SUBMITTED', occurredAt: created.submittedAt,
        } });
        return { ...created, status: created.status.toLowerCase() };
      },
      appendAuditEvent: async (tx: Prisma.TransactionClient, event: any) => tx.auditEvent.create({ data: {
        actorUserId: event.actorUserId, scope: event.scope, estateId: event.estateId, action: event.action,
        targetType: event.targetType, targetId: event.targetId, outcome: event.outcome, occurredAt: new Date(event.occurredAt),
      } }),
      enqueueRequestNotice: async (tx: Prisma.TransactionClient, event: any) => tx.estateMaintenanceNoticeOutbox.create({ data: {
        estateId: event.estateId, requestId: event.requestId, eventType: 'maintenance.request_submitted',
        payload: { requestId: event.requestId, estateId: event.estateId, propertyId: event.propertyId, requesterUserId: event.requesterUserId },
      } }),
      readMaintenanceCreationIdempotency: async (tx: Prisma.TransactionClient, scope: any) => tx.estateMaintenanceIdempotency.findUnique({
        where: { actorUserId_estateId_idempotencyKeyHash: { actorUserId: scope.actorUserId, estateId: scope.estateId, idempotencyKeyHash: scope.idempotencyKeyHash } },
      }),
      claimMaintenanceCreationIdempotency: async (tx: Prisma.TransactionClient, scope: any) => tx.estateMaintenanceIdempotency.upsert({
        where: { actorUserId_estateId_idempotencyKeyHash: { actorUserId: scope.actorUserId, estateId: scope.estateId, idempotencyKeyHash: scope.idempotencyKeyHash } },
        create: { actorUserId: scope.actorUserId, estateId: scope.estateId, idempotencyKeyHash: scope.idempotencyKeyHash, payloadHash: scope.payloadHash, state: 'claimed' },
        update: {},
      }),
      completeMaintenanceCreationIdempotency: async (tx: Prisma.TransactionClient, value: any) => tx.estateMaintenanceIdempotency.update({
        where: { id: value.claim.id }, data: { payloadHash: value.payloadHash, state: 'completed', requestId: value.result.requestId, result: value.result },
      }),
    });

    try {
      const result = await submit({ actorUserId, estateId: input.estateId, propertyId: input.propertyId,
        category: input.category, priority: input.priority, description: input.description,
        attachmentIds: [], idempotencyKey });
      return { ...result, reference: `MNT-${String(result.requestId).replaceAll('-', '').slice(0, 10).toUpperCase()}` };
    } catch (error) {
      this.throwDomainError(error);
    }
  }

  async listMine(actorUserId: string, estateId: string, page: number, pageSize: number) {
    const access = await this.resolvePropertyAccess(this.prisma, actorUserId, estateId);
    if (!access) throw new ForbiddenException('An active resident, tenant or verified owner relationship is required to view maintenance requests.');
    const where: Prisma.EstateMaintenanceRequestWhereInput = {
      estateId, requesterUserId: actorUserId, propertyId: { in: access.propertyIds },
    };
    const [requests, total] = await this.prisma.$transaction([
      this.prisma.estateMaintenanceRequest.findMany({ where, include: {
        property: { select: { code: true, unitNumber: true } },
        updates: { where: { visibility: 'RESIDENT_VISIBLE' }, orderBy: { occurredAt: 'asc' }, take: 100 },
      }, orderBy: { submittedAt: 'desc' }, skip: (page - 1) * pageSize, take: pageSize }),
      this.prisma.estateMaintenanceRequest.count({ where }),
    ]);
    return { items: requests.map((request) => ({
      id: request.id, requestId: request.id, estateId, reference: request.reference, category: request.category,
      priority: request.priority, description: request.description, status: request.status.toLowerCase(),
      propertyLabel: [request.property.code, request.property.unitNumber].filter(Boolean).join(' Â· '),
      submittedAt: request.submittedAt.toISOString(), updatedAt: request.updatedAt.toISOString(),
      residentVisibleUpdates: request.updates.map((update) => ({ body: update.body, occurredAt: update.occurredAt.toISOString() })),
    })), page, pageSize, total, totalPages: Math.ceil(total / pageSize) };
  }

  async listMyLandlordPropertyMaintenance(actorUserId: string, page: number, pageSize: number) {
    return this.prisma.$transaction(async (tx) => {
      const today = currentDate();
      const memberships = await tx.estateMembership.findMany({
        where: {
          userId: actorUserId,
          role: 'LANDLORD',
          status: 'ACTIVE',
          estate: { status: 'ACTIVE' },
        },
        select: { estateId: true },
      });
      if (memberships.length === 0) {
        throw new ForbiddenException('Active landlord access is required to view property maintenance.');
      }

      const estateIds = memberships.map((membership) => membership.estateId);
      const ownerships = await tx.estateOwnershipInterest.findMany({
        where: {
          ownerUserId: actorUserId,
          estateId: { in: estateIds },
          status: 'ACTIVE',
          verificationStatus: 'VERIFIED',
          effectiveFrom: { lte: today },
          OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }],
          estate: { status: 'ACTIVE' },
          property: { status: { not: 'ARCHIVED' } },
        },
        select: { estateId: true, propertyId: true },
      });
      if (ownerships.length === 0) {
        return { items: [], page, pageSize, total: 0, totalPages: 0 };
      }

      const allowedPropertyScopes = new Set(
        ownerships.map(({ estateId, propertyId }) => `${estateId}:${propertyId}`),
      );
      const where: Prisma.EstateMaintenanceRequestWhereInput = {
        OR: ownerships.map(({ estateId, propertyId }) => ({ estateId, propertyId })),
      };
      const [requests, total] = await Promise.all([
        tx.estateMaintenanceRequest.findMany({
          where,
          include: {
            property: { select: { code: true, unitNumber: true } },
            updates: {
              where: { visibility: 'RESIDENT_VISIBLE' },
              orderBy: { occurredAt: 'asc' },
              take: 100,
            },
          },
          orderBy: [{ submittedAt: 'desc' }, { id: 'desc' }],
          skip: (page - 1) * pageSize,
          take: pageSize,
        }),
        tx.estateMaintenanceRequest.count({ where }),
      ]);

      const seenRequestIds = new Set<string>();
      const items = requests.map((request) => {
        if (
          !allowedPropertyScopes.has(`${request.estateId}:${request.propertyId}`) ||
          seenRequestIds.has(request.id)
        ) {
          throw new ConflictException('The maintenance list did not match its verified ownership scope.');
        }
        seenRequestIds.add(request.id);
        return {
          id: request.id,
          reference: request.reference,
          propertyLabel: [request.property.code, request.property.unitNumber]
            .filter(Boolean)
            .join(' Â· '),
          category: request.category,
          priority: request.priority,
          description: request.description,
          status: request.status.toLowerCase(),
          submittedAt: request.submittedAt.toISOString(),
          updatedAt: request.updatedAt.toISOString(),
          residentVisibleUpdates: request.updates.map((update) => ({
            body: update.body,
            occurredAt: update.occurredAt.toISOString(),
          })),
        };
      });

      return { items, page, pageSize, total, totalPages: Math.ceil(total / pageSize) };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }

  async listQueue(actorUserId: string, estateId: string, query: MaintenanceQueueQueryDto) {
    await this.requireManager(actorUserId, estateId);
    const status = query.status && query.status !== 'open' ? STATUS_TO_DB[query.status] : undefined;
    if (query.status && query.status !== 'open' && !status) throw new BadRequestException('Choose a supported maintenance status.');
    if (query.priority && !['low', 'normal', 'high', 'urgent'].includes(query.priority)) throw new BadRequestException('Choose a supported maintenance priority.');
    const search = query.search?.trim();
    const statusFilter = query.status === 'open'
      ? { notIn: ['RESOLVED', 'CLOSED', 'REJECTED'] }
      : status;
    const where: Prisma.EstateMaintenanceRequestWhereInput = {
      estateId, ...(statusFilter ? { status: statusFilter as any } : {}), ...(query.priority ? { priority: query.priority } : {}),
      ...(search ? { OR: [
        { reference: { contains: search, mode: 'insensitive' } }, { description: { contains: search, mode: 'insensitive' } },
        { category: { contains: search, mode: 'insensitive' } }, { priority: { contains: search, mode: 'insensitive' } },
        { property: { code: { contains: search, mode: 'insensitive' } } },
        { property: { unitNumber: { contains: search, mode: 'insensitive' } } },
        { requester: { displayName: { contains: search, mode: 'insensitive' } } },
        { assignee: { displayName: { contains: search, mode: 'insensitive' } } },
      ] } : {}),
    };
    const [requests, total] = await this.prisma.$transaction([
      this.prisma.estateMaintenanceRequest.findMany({ where, include: {
        property: { select: { code: true, unitNumber: true } }, requester: { select: { displayName: true } },
        assignee: { select: { displayName: true } }, updates: { where: { visibility: 'RESIDENT_VISIBLE' }, orderBy: { occurredAt: 'asc' }, take: 100 },
      }, orderBy: { submittedAt: 'desc' }, skip: (query.page - 1) * query.pageSize, take: query.pageSize }),
      this.prisma.estateMaintenanceRequest.count({ where }),
    ]);
    const assignableStaff = await this.prisma.estateMembership.findMany({
      where: { estateId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES] }, estate: { status: 'ACTIVE' } },
      orderBy: { user: { displayName: 'asc' } },
      select: { user: { select: { id: true, displayName: true } } },
      take: 100,
    });
    return { items: requests.map((request) => ({
      id: request.id, estateId, propertyId: request.propertyId, reference: request.reference,
      category: request.category, priority: request.priority, status: request.status.toLowerCase(), description: request.description,
      propertyLabel: [request.property.code, request.property.unitNumber].filter(Boolean).join(' Â· '),
      requesterDisplayName: request.requester.displayName, assigneeUserId: request.assigneeUserId,
      assigneeDisplayName: request.assignee?.displayName ?? null, submittedAt: request.submittedAt.toISOString(),
      residentVisibleUpdates: request.updates.map((update) => ({ body: update.body, occurredAt: update.occurredAt.toISOString() })),
      allowedCommands: this.allowedCommands(request.status.toLowerCase()),
    })), assignableStaff: assignableStaff.map((membership) => ({ userId: membership.user.id, displayName: membership.user.displayName })),
      page: query.page, pageSize: query.pageSize, total, totalPages: Math.ceil(total / query.pageSize) };
  }

  async review(actorUserId: string, estateId: string, requestId: string, input: ReviewMaintenanceRequestDto) {
    await this.requireManager(actorUserId, estateId);
    try {
      return await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM estate_maintenance_requests WHERE id = ${requestId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const record = await tx.estateMaintenanceRequest.findFirst({ where: { id: requestId, estateId } });
        if (!record) throw new NotFoundException('Maintenance request not found in this estate.');
        const request = { id: record.id, estateId: record.estateId, propertyId: record.propertyId,
          status: record.status.toLowerCase(), assigneeUserId: record.assigneeUserId };
        const command = input.command as string | undefined;
        if (input.assigneeUserId && command !== 'assign') {
          throw new BadRequestException('Choose the assign action when selecting an assignee.');
        }
        let assignee: { userId: string; estateId: string; status: string } | undefined;
        if (input.assigneeUserId) {
          const membership = await tx.estateMembership.findFirst({ where: {
            userId: input.assigneeUserId, estateId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES] }, estate: { status: 'ACTIVE' },
          }, select: { userId: true, estateId: true } });
          if (!membership) throw new BadRequestException('The assignee must be an active manager in this estate.');
          assignee = { userId: membership.userId, estateId: membership.estateId, status: 'active' };
        }
        const now = new Date();
        const transition = command ? planMaintenanceTransition(request, {
          command, actorUserId, now, reason: input.reason, resolutionSummary: input.resolutionSummary,
          assignee, mayReopen: true,
        }) : null;
        const residentUpdate = input.residentUpdate?.trim();
        const internalNote = input.internalNote?.trim();
        if (!transition && !input.assigneeUserId && !residentUpdate && !internalNote) throw new BadRequestException('Provide a status change, assignment or update.');
        const updatePlans = [
          ...(residentUpdate ? [planMaintenanceUpdate(request, { actorUserId, now, body: residentUpdate, visibility: 'resident_visible' })] : []),
          ...(internalNote ? [planMaintenanceUpdate(request, { actorUserId, now, body: internalNote, visibility: 'internal', mayAddInternalNote: true })] : []),
        ];
        const status = transition?.nextStatus ? STATUS_TO_DB[transition.nextStatus] : record.status;
        const assigneeUserId = input.assigneeUserId ?? record.assigneeUserId;
        const updated = await tx.estateMaintenanceRequest.update({ where: { id: record.id }, data: {
          status: status as any, assigneeUserId,
        } });
        if (transition) await tx.estateMaintenanceHistory.create({ data: {
          requestId, actorUserId, fromStatus: record.status, toStatus: status as any,
          reason: input.reason?.trim() || null, occurredAt: now,
        } });
        for (const effect of transition?.effects ?? []) {
          if (effect.resolutionSummary) await tx.estateMaintenanceUpdate.create({ data: {
            requestId, authorId: actorUserId, visibility: 'RESIDENT_VISIBLE', body: effect.resolutionSummary, occurredAt: now,
          } });
        }
        for (const plan of updatePlans) for (const effect of plan.effects) await tx.estateMaintenanceUpdate.create({ data: {
          requestId, authorId: actorUserId, visibility: effect.visibility === 'internal' ? 'INTERNAL' : 'RESIDENT_VISIBLE',
          body: effect.body, occurredAt: new Date(effect.occurredAt),
        } });
        for (const event of [transition?.auditEvent, ...updatePlans.map((plan: any) => plan.auditEvent)].filter(Boolean)) {
          await tx.auditEvent.create({ data: {
            actorUserId: event.actorUserId, scope: 'estate', estateId, action: event.action,
            targetType: 'maintenance_request', targetId: requestId, outcome: 'success', reason: event.reason ?? null,
            occurredAt: new Date(event.occurredAt),
          } });
        }
        if (transition || residentUpdate) await tx.estateMaintenanceNoticeOutbox.create({ data: {
          estateId, requestId, eventType: 'maintenance.request_updated',
          payload: { requestId, estateId, status: updated.status.toLowerCase(), residentUpdate: residentUpdate ?? null },
        } });
        return { requestId, estateId, status: updated.status.toLowerCase(), assigneeUserId: updated.assigneeUserId, updatedAt: updated.updatedAt.toISOString() };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      this.throwDomainError(error);
    }
  }

  private async resolvePropertyAccess(tx: Prisma.TransactionClient | PrismaService, actorUserId: string, estateId: string) {
    const today = currentDate();
    const [occupancies, tenancies, ownerships] = await Promise.all([
      tx.propertyOccupancy.findMany({ where: { residentId: actorUserId, estateId, status: 'ACTIVE', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
      tx.estateTenancy.findMany({ where: { tenantUserId: actorUserId, estateId, status: 'ACTIVE', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
      tx.estateOwnershipInterest.findMany({ where: { ownerUserId: actorUserId, estateId, status: 'ACTIVE', verificationStatus: 'VERIFIED', effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }], estate: { status: 'ACTIVE' }, property: { status: { not: 'ARCHIVED' } } }, select: { propertyId: true } }),
    ]);
    const propertyIds = [...new Set([...occupancies, ...tenancies, ...ownerships].map((record) => record.propertyId))];
    return propertyIds.length ? { estateId, userId: actorUserId, propertyIds, active: true, mayViewMaintenance: true, maySubmitMaintenance: true } : null;
  }

  private async requireManager(actorUserId: string, estateId: string, tx: Prisma.TransactionClient | PrismaService = this.prisma) {
    const membership = await tx.estateMembership.findFirst({ where: {
      userId: actorUserId, estateId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES] }, estate: { status: 'ACTIVE' },
    }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate management access is required.');
  }

  private allowedCommands(status: string): string[] {
    const commands: Record<string, string[]> = {
      submitted: ['review', 'reject'], under_review: ['assign', 'reject'], assigned: ['start'],
      in_progress: ['await_parts', 'resolve'], awaiting_parts: ['resume'], resolved: ['close', 'reopen'],
      closed: ['reopen'], reopened: ['assign'], rejected: [],
    };
    return commands[status] ?? [];
  }

  private throwDomainError(error: unknown): never {
    const code = (error as { code?: string })?.code;
    if (error instanceof BadRequestException || error instanceof ForbiddenException || error instanceof NotFoundException) throw error;
    if (code === 'RESIDENT_ACCESS_DENIED') throw new ForbiddenException((error as Error).message);
    if (code === 'PROPERTY_NOT_FOUND' || code === 'REQUEST_NOT_FOUND') throw new NotFoundException((error as Error).message);
    if (code === 'IDEMPOTENCY_KEY_REUSED') throw new ConflictException((error as Error).message);
    if (code && typeof code === 'string') throw new BadRequestException((error as Error).message);
    throw error;
  }
}

