import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateEstateGateDto } from './gate-security.dto.js';

const { createGateVisitCheckInUseCase } = require('../../modules/visitors/check-in-gate-visit.js') as { createGateVisitCheckInUseCase: (ports: any) => (input: any) => Promise<any> };
const { createGateVisitCheckOutUseCase } = require('../../modules/visitors/check-out-gate-visit.js') as { createGateVisitCheckOutUseCase: (ports: any) => (input: any) => Promise<any> };
const { createCurrentGateVisitorsUseCase } = require('../../modules/visitors/list-current-gate-visitors.js') as { createCurrentGateVisitorsUseCase: (ports: any) => (input: any) => Promise<any> };
const { createManualAdmissionUseCase, ManualAdmissionUseCaseError } = require('../../modules/visitors/create-manual-admission.js') as { createManualAdmissionUseCase: (ports: any) => (input: any) => Promise<any>; ManualAdmissionUseCaseError: new (...args: any[]) => Error & { code: string } };

const MANAGER_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER'] as const;
const txRetry = async <T>(prisma: PrismaService, work: (tx: Prisma.TransactionClient) => Promise<T>) => {
  for (let attempt = 0; ; attempt += 1) {
    try { return await prisma.$transaction(work, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }); }
    catch (error) { if ((error as { code?: string })?.code !== 'P2034' || attempt >= 2) throw error; }
  }
};

@Injectable()
export class GateSecurityService {
  constructor(private readonly prisma: PrismaService) {}

  async listSecurityOfficers(actorUserId: string, estateId: string) {
    await this.requireManager(actorUserId, estateId);
    const memberships = await this.prisma.estateMembership.findMany({
      where: { estateId, role: 'SECURITY_OFFICER', status: 'ACTIVE', estate: { status: 'ACTIVE' } },
      select: { user: { select: { id: true, displayName: true } } },
      orderBy: { user: { displayName: 'asc' } }, take: 200,
    });
    return { items: memberships.map(({ user }) => ({ userId: user.id, displayName: user.displayName })) };
  }

  async listEstateGates(actorUserId: string, estateId: string) {
    await this.requireManager(actorUserId, estateId);
    const items = await this.prisma.estateGate.findMany({ where: { estateId, active: true }, select: { id: true, estateId: true, code: true, name: true }, orderBy: { code: 'asc' }, take: 100 });
    return { items };
  }

  async createGate(actorUserId: string, estateId: string, input: CreateEstateGateDto) {
    await this.requireManager(actorUserId, estateId);
    const code = input.code.trim().toUpperCase();
    const name = input.name.trim();
    try {
      const gate = await this.prisma.estateGate.create({ data: { estateId, code, name } });
      await this.prisma.auditEvent.create({ data: { actorUserId, scope: 'estate', estateId, action: 'security.gate.create', targetType: 'estate_gate', targetId: gate.id, outcome: 'success', occurredAt: gate.createdAt, metadata: { gateCode: code } } });
      return { id: gate.id, estateId, code, name, active: gate.active };
    } catch (error) { if ((error as { code?: string })?.code === 'P2002') throw new ConflictException('A gate with this code already exists in the estate.'); throw error; }
  }

  async assignStaff(actorUserId: string, estateId: string, gateId: string, userId: string) {
    await this.requireManager(actorUserId, estateId);
    const staff = await this.prisma.estateMembership.findFirst({ where: { estateId, userId, role: 'SECURITY_OFFICER', status: 'ACTIVE', estate: { status: 'ACTIVE' } }, select: { id: true } });
    const gate = await this.prisma.estateGate.findFirst({ where: { id: gateId, estateId, active: true }, select: { id: true } });
    if (!staff || !gate) throw new NotFoundException('Active gate or security officer not found in this estate.');
    const now = new Date();
    const existing = await this.prisma.estateGateAssignment.findFirst({ where: { estateId, gateId, userId, activeTo: null, activeFrom: { lte: now } }, select: { id: true } });
    if (existing) throw new ConflictException('This officer is already assigned to this gate.');
    const assignment = await this.prisma.estateGateAssignment.create({ data: { estateId, gateId, userId, assignedById: actorUserId, activeFrom: now } });
    await this.prisma.auditEvent.create({ data: { actorUserId, scope: 'estate', estateId, action: 'security.gate.assign', targetType: 'gate_assignment', targetId: assignment.id, outcome: 'success', occurredAt: now, metadata: { gateId, assignedUserId: userId } } });
    return { id: assignment.id, estateId, gateId, userId, activeFrom: now.toISOString() };
  }

  async listMyGates(actorUserId: string, estateId: string) {
    const now = new Date();
    const assignments = await this.prisma.estateGateAssignment.findMany({
      where: { estateId, userId: actorUserId, activeTo: null, activeFrom: { lte: now }, gate: { active: true, estate: { status: 'ACTIVE' } }, estate: { status: 'ACTIVE' }, user: { estateMemberships: { some: { estateId, role: 'SECURITY_OFFICER', status: 'ACTIVE' } } } },
      select: { gate: { select: { id: true, estateId: true, code: true, name: true } } }, orderBy: { gate: { code: 'asc' } }, take: 100,
    });
    return { items: assignments.map((assignment) => assignment.gate) };
  }

  async checkIn(actorUserId: string, estateId: string, gateId: string, credential: string, idempotencyKey: string | undefined, requestContext: any) {
    const run = createGateVisitCheckInUseCase({
      transaction: (work: (tx: Prisma.TransactionClient) => Promise<any>) => txRetry(this.prisma, work),
      resolveAssignedGateAccess: async (tx: Prisma.TransactionClient, scope: any) => {
        const now = new Date();
        const [gate, membership, assignment] = await Promise.all([
          tx.estateGate.findFirst({ where: { id: scope.gateId, estateId: scope.estateId, active: true, estate: { status: 'ACTIVE' } } }),
          tx.estateMembership.findFirst({ where: { estateId: scope.estateId, userId: scope.actorUserId, role: 'SECURITY_OFFICER', status: 'ACTIVE' }, select: { id: true } }),
          tx.estateGateAssignment.findFirst({ where: { estateId: scope.estateId, gateId: scope.gateId, userId: scope.actorUserId, activeTo: null, activeFrom: { lte: now } }, select: { id: true } }),
        ]);
        return { actorUserId: scope.actorUserId, estateId: scope.estateId, gateId: scope.gateId, gate, allowed: Boolean(gate && membership && assignment) };
      },
      enforceVerificationRateLimit: async (scope: any) => {
        const now = new Date();
        const windowMs = 5 * 60 * 1000;
        const windowStartedAt = new Date(Math.floor(now.getTime() / windowMs) * windowMs);
        const deviceHash = createHash('sha256').update(`gate-device:v1:${scope.requestContext.remoteAddress}|${scope.requestContext.userAgent}`, 'utf8').digest('hex');
        const key = { estateId: scope.estateId, gateId: scope.gateId, deviceHash, credentialFingerprint: scope.credentialFingerprint, windowStartedAt };
        const attempt = await this.prisma.estateGateVerificationAttempt.upsert({ where: { estateId_gateId_deviceHash_credentialFingerprint_windowStartedAt: key }, create: { ...key, attempts: 1 }, update: { attempts: { increment: 1 } }, select: { attempts: true } });
        return attempt.attempts <= 8;
      },
      findPassForVerificationUpdate: async (tx: Prisma.TransactionClient, scope: any) => {
        await tx.$queryRaw`SELECT id FROM estate_visitor_passes WHERE estate_id = ${scope.estateId}::uuid AND credential_hash = ${scope.credentialHash} FOR UPDATE`;
        const pass = await tx.estateVisitorPass.findFirst({ where: { estateId: scope.estateId, credentialHash: scope.credentialHash }, include: { property: { select: { code: true, unitNumber: true } }, host: { select: { displayName: true } } } });
        return pass ? { ...pass, propertyLabel: [pass.property.code, pass.property.unitNumber].filter(Boolean).join(' Â· '), hostDisplayName: pass.host.displayName } : null;
      },
      readCheckInIdempotency: async (tx: Prisma.TransactionClient, scope: any) => tx.estateGateCheckInIdempotency.findUnique({ where: { actorUserId_estateId_gateId_idempotencyKeyHash: { actorUserId: scope.actorUserId, estateId: scope.estateId, gateId: scope.gateId, idempotencyKeyHash: scope.idempotencyKeyHash } } }),
      claimCheckInIdempotency: async (tx: Prisma.TransactionClient, scope: any) => tx.estateGateCheckInIdempotency.upsert({
        where: { actorUserId_estateId_gateId_idempotencyKeyHash: { actorUserId: scope.actorUserId, estateId: scope.estateId, gateId: scope.gateId, idempotencyKeyHash: scope.idempotencyKeyHash } },
        create: { ...scope, state: 'claimed', expiresAt: new Date(Date.now() + 10 * 60 * 1000) }, update: {},
      }),
      completeCheckInIdempotency: async (tx: Prisma.TransactionClient, value: any) => tx.estateGateCheckInIdempotency.update({ where: { id: value.claim.id }, data: { credentialHash: value.credentialHash, result: value.result, state: 'completed' } }),
      findActiveVisitForPass: async (tx: Prisma.TransactionClient, scope: any) => tx.estateVisitorVisit.findFirst({ where: { estateId: scope.estateId, passId: scope.passId, status: 'checked_in' }, select: { id: true, estateId: true, passId: true, status: true } }),
      consumePassUse: async (tx: Prisma.TransactionClient, value: any) => {
        const updated = await tx.estateVisitorPass.updateMany({ where: { id: value.pass.id, estateId: value.pass.estateId, useCount: value.effect.expectedUseCount, revokedAt: null }, data: { useCount: value.effect.newUseCount } });
        return updated.count === 1 ? tx.estateVisitorPass.findUnique({ where: { id: value.pass.id }, select: { id: true, estateId: true, useCount: true } }) : null;
      },
      createCheckedInVisit: async (tx: Prisma.TransactionClient, value: any) => {
        const effect = value.effect;
        const visit = await tx.estateVisitorVisit.create({ data: { id: effect.visitId, estateId: effect.estateId, passId: effect.passId, propertyId: effect.propertyId, gateId: effect.gateId, admissionType: 'pass', visitorDisplayName: effect.visitorName, status: 'checked_in', checkedInByUserId: effect.checkedInByUserId, checkedInAt: new Date(effect.checkedInAt) }, select: { id: true, estateId: true, passId: true, gateId: true, status: true, checkedInAt: true, checkedInByUserId: true } });
        return { ...visit, checkedInAt: visit.checkedInAt.toISOString() };
      },
      appendAccessEvent: async (tx: Prisma.TransactionClient, event: any) => tx.estateAccessEvent.create({ data: {
        estateId: event.estateId, passId: event.passId ?? null, visitId: event.visitId ?? null, propertyId: event.propertyId ?? null,
        gateId: event.gateId, staffUserId: event.staffUserId, eventKind: event.eventKind, reasonCode: event.reasonCode ?? null, occurredAt: new Date(event.occurredAt),
      } }),
      appendAuditEvent: async (tx: Prisma.TransactionClient, event: any) => tx.auditEvent.create({ data: {
        actorUserId: event.actorUserId, scope: event.scope, estateId: event.estateId, action: event.action,
        targetType: event.targetType, targetId: event.targetId, outcome: event.outcome, occurredAt: new Date(event.occurredAt),
        metadata: { gateId: event.gateId, reasonCode: event.reasonCode ?? null },
      } }),
      generateVisitId: async () => randomUUID(),
    });
    try { return await run({ actorUserId, estateId, gateId, credential, idempotencyKey, requestContext }); }
    catch (error) {
      const code = (error as { code?: string })?.code;
      if (code === 'INVALID_INPUT') throw new BadRequestException('Provide a valid visitor pass code and request key.');
      if (code === 'GATE_ACCESS_DENIED') throw new ForbiddenException('The staff member is not assigned to this gate.');
      if (code === 'INVALID_CREDENTIAL') throw new BadRequestException('This credential cannot be admitted.');
      if (code === 'RATE_LIMITED') throw new BadRequestException('Too many verification attempts. Please wait and try again.');
      if (code === 'IDEMPOTENCY_KEY_REUSED') throw new ConflictException((error as Error).message);
      if (code === 'P2002' || code === 'P2034') throw new ConflictException('The visitor check-in changed concurrently. Retry with the same request key.');
      throw error;
    }
  }

  async checkOut(actorUserId: string, estateId: string, gateId: string, visitId: string) {
    const run = createGateVisitCheckOutUseCase({
      transaction: (work: (tx: Prisma.TransactionClient) => Promise<any>) => txRetry(this.prisma, work),
      resolveAssignedGateAccess: async (tx: Prisma.TransactionClient, scope: any) => this.resolveAssignedGate(tx, scope),
      findActiveVisitForUpdate: async (tx: Prisma.TransactionClient, scope: any) => {
        await tx.$queryRaw`SELECT id FROM estate_visitor_visits WHERE id = ${scope.visitId}::uuid AND estate_id = ${scope.estateId}::uuid AND gate_id = ${scope.gateId}::uuid AND status = 'checked_in' FOR UPDATE`;
        const visit = await tx.estateVisitorVisit.findFirst({ where: { id: scope.visitId, estateId: scope.estateId, gateId: scope.gateId, status: 'checked_in' } });
        return visit ? { ...visit, checkedInAt: visit.checkedInAt.toISOString() } : null;
      },
      commitVisitCheckOut: async (tx: Prisma.TransactionClient, value: any) => {
        const result = await tx.estateVisitorVisit.updateMany({ where: { id: value.visit.id, estateId: value.visit.estateId, gateId: value.visit.gateId, status: 'checked_in' }, data: { status: 'checked_out', checkedOutByUserId: value.effect.checkedOutByUserId, checkedOutAt: new Date(value.effect.checkedOutAt) } });
        if (!result.count) return null;
        const updated = await tx.estateVisitorVisit.findUniqueOrThrow({ where: { id: value.visit.id } });
        return { ...updated, checkedOutAt: updated.checkedOutAt!.toISOString(), status: updated.status, checkedOutByUserId: updated.checkedOutByUserId };
      },
      appendAccessEvent: (tx: Prisma.TransactionClient, event: any) => this.appendGateAccessEvent(tx, event),
      appendAuditEvent: (tx: Prisma.TransactionClient, event: any) => this.appendGateAudit(tx, event),
    });
    try { return await run({ actorUserId, estateId, gateId, visitId }); }
    catch (error) { this.mapGateError(error); }
  }

  async listCurrent(actorUserId: string, estateId: string, gateId: string) {
    const run = createCurrentGateVisitorsUseCase({
      transaction: <T>(work: (tx: Prisma.TransactionClient) => Promise<T>) => this.prisma.$transaction(work),
      resolveAssignedGateAccess: async (tx: Prisma.TransactionClient, scope: any) => this.resolveAssignedGate(tx, scope),
      queryCurrentGateVisits: async (tx: Prisma.TransactionClient, scope: any) => {
        const visits = await tx.estateVisitorVisit.findMany({ where: { estateId: scope.gateContext.estateId, gateId: scope.gateContext.gateId, status: 'checked_in' }, orderBy: { checkedInAt: 'asc' }, take: scope.limit });
        return visits.map((visit) => ({ ...visit, checkedInAt: visit.checkedInAt.toISOString() }));
      },
      loadPassForGateVisit: async (tx: Prisma.TransactionClient, scope: any) => scope.visit.passId
        ? tx.estateVisitorPass.findFirst({ where: { id: scope.visit.passId, estateId: scope.gateContext.estateId }, select: { id: true, estateId: true, hostUserId: true, propertyId: true, visitorDisplayName: true, vehicleSummary: true } })
        : null,
      projectCurrentGateVisitor: async (value: any) => {
        const propertyId = value.pass?.propertyId ?? value.visit.propertyId;
        const property = await value.tx.estateProperty.findFirst({ where: { id: propertyId, estateId: value.gateContext.estateId }, select: { code: true, unitNumber: true } });
        const propertyLabel = property ? [property.code, property.unitNumber].filter(Boolean).join(' Â· ') : '';
        if (!value.pass) {
          return { visitId: value.visit.id, estateId: value.visit.estateId, gateId: value.visit.gateId,
            propertyId, visitorName: value.visit.visitorDisplayName, propertyLabel, checkedInAt: value.visit.checkedInAt };
        }
        const host = await value.tx.user.findUnique({ where: { id: value.pass.hostUserId }, select: { displayName: true } });
        return { visitId: value.visit.id, passId: value.pass.id, hostUserId: value.pass.hostUserId, propertyId,
          checkedInAt: value.visit.checkedInAt, hostDisplayName: host?.displayName ?? 'Estate host', propertyLabel };
      },
    });
    try { return await run({ actorUserId, estateId, gateId }); }
    catch (error) { this.mapGateError(error); }
  }

  async listExpected(actorUserId: string, estateId: string, gateId: string) {
    const access = await this.prisma.$transaction((tx) =>
      this.resolveAssignedGate(tx, { actorUserId, estateId, gateId }),
    );
    if (!access.allowed) {
      throw new ForbiddenException('The staff member is not assigned to this gate.');
    }

    const now = new Date();
    const passes = await this.prisma.estateVisitorPass.findMany({
      where: {
        estateId,
        validFrom: { lte: now },
        validUntil: { gte: now },
        revokedAt: null,
        property: { estateId, archivedAt: null },
        visits: { none: { status: 'checked_in' } },
      },
      select: {
        visitorDisplayName: true,
        validUntil: true,
        allowedUses: true,
        useCount: true,
        vehicleSummary: true,
        property: { select: { code: true, unitNumber: true } },
        host: { select: { displayName: true } },
      },
      orderBy: [{ validUntil: 'asc' }, { createdAt: 'asc' }],
      take: 500,
    });

    return {
      items: passes
        .filter((pass) => pass.useCount < pass.allowedUses)
        .slice(0, 100)
        .map((pass) => ({
          visitorName: pass.visitorDisplayName,
          propertyLabel: [pass.property.code, pass.property.unitNumber]
            .filter(Boolean)
            .join(' Â· '),
          hostDisplayName: pass.host.displayName,
          validUntil: pass.validUntil.toISOString(),
          vehicleSummary: pass.vehicleSummary,
        })),
    };
  }

  async manualAdmission(actorUserId: string, estateId: string, gateId: string,
    input: { visitorDisplayName: string; propertyReference: string; reason: string },
    idempotencyKey: string | undefined) {
    const run = createManualAdmissionUseCase({
      transaction: (work: (tx: Prisma.TransactionClient) => Promise<any>) => txRetry(this.prisma, work),
      requireManualAdmissionPermission: async (tx: Prisma.TransactionClient, scope: any) => this.resolveAssignedGate(tx, scope),
      getManualAdmissionPolicy: async () => ({
        enabled: (process.env.GATE_MANUAL_ADMISSION_ENABLED ?? 'true').toLowerCase() !== 'false',
      }),
      resolveAdmissionProperty: async (tx: Prisma.TransactionClient, scope: any) => {
        const reference = scope.propertyReference.trim();
        const property = await tx.estateProperty.findFirst({
          where: {
            estateId: scope.estateId,
            archivedAt: null,
            OR: [{ code: reference }, { code: reference.toUpperCase() }, { unitNumber: reference }],
          },
          select: { id: true, estateId: true, code: true, unitNumber: true },
        });
        return property
          ? { ...property, displayLabel: [property.code, property.unitNumber].filter(Boolean).join(' Â· ') }
          : null;
      },
      generateVisitId: async () => randomUUID(),
      createManualAdmissionVisit: async (tx: Prisma.TransactionClient, value: any) => {
        const effect = value.effect;
        const visit = await tx.estateVisitorVisit.create({ data: {
          id: effect.visitId, estateId: effect.estateId, passId: null,
          propertyId: effect.propertyId, gateId: effect.gateId,
          admissionType: 'manual', visitorDisplayName: effect.visitorName,
          status: 'checked_in', checkedInByUserId: effect.checkedInByUserId,
          checkedInAt: new Date(effect.checkedInAt),
        }, select: { id: true, estateId: true, gateId: true, passId: true, propertyId: true,
          admissionType: true, visitorDisplayName: true, status: true, checkedInAt: true, checkedInByUserId: true } });
        return { ...visit, checkedInAt: visit.checkedInAt.toISOString() };
      },
      appendAccessEvent: (tx: Prisma.TransactionClient, event: any) => this.appendGateAccessEvent(tx, event),
      appendAuditEvent: (tx: Prisma.TransactionClient, event: any) => this.appendGateAudit(tx, event),
      readManualAdmissionIdempotency: (tx: Prisma.TransactionClient, scope: any) =>
        tx.estateGateManualAdmissionIdempotency.findUnique({
          where: { actorUserId_estateId_gateId_idempotencyKeyHash: scope },
        }),
      claimManualAdmissionIdempotency: (tx: Prisma.TransactionClient, scope: any) =>
        tx.estateGateManualAdmissionIdempotency.upsert({
          where: { actorUserId_estateId_gateId_idempotencyKeyHash: {
            actorUserId: scope.actorUserId, estateId: scope.estateId,
            gateId: scope.gateId, idempotencyKeyHash: scope.idempotencyKeyHash,
          } },
          create: { ...scope, state: 'claimed', expiresAt: new Date(Date.now() + 10 * 60 * 1000) },
          update: {},
        }),
      completeManualAdmissionIdempotency: (tx: Prisma.TransactionClient, value: any) =>
        tx.estateGateManualAdmissionIdempotency.update({
          where: { id: value.claim.id },
          data: { state: 'completed', result: value.result },
        }),
    });
    try {
      return await run({ actorUserId, estateId, gateId, ...input, idempotencyKey });
    } catch (error) {
      const code = (error as { code?: string })?.code;
      if (code === 'INVALID_INPUT') throw new BadRequestException('Provide a visitor name, an estate property reference and a reason of 10 to 500 characters.');
      if (code === 'MANUAL_ADMISSION_DENIED') throw new ForbiddenException('Manual admission is not allowed for this gate assignment.');
      if (code === 'MANUAL_ADMISSION_DISABLED') throw new ForbiddenException('Manual admission is disabled for this estate.');
      if (code === 'PROPERTY_NOT_AVAILABLE') throw new NotFoundException('Choose an active property in this estate.');
      if (code === 'IDEMPOTENCY_KEY_REUSED') throw new ConflictException((error as Error).message);
      if (code === 'P2002' || code === 'P2034') throw new ConflictException('The admission changed concurrently. Retry with the same request key.');
      throw error;
    }
  }

  async listAccessEvents(actorUserId: string, estateId: string, query: {
    gateId?: string; eventKind?: string; from?: string; to?: string; page: number; pageSize: number;
  }) {
    const manager = await this.prisma.estateMembership.findFirst({
      where: { estateId, userId: actorUserId, role: { in: [...MANAGER_ROLES] }, status: 'ACTIVE', estate: { status: 'ACTIVE' } },
      select: { id: true },
    });
    let assignedGateIds: string[] | undefined;
    if (!manager) {
      assignedGateIds = (await this.prisma.estateGateAssignment.findMany({
        where: { estateId, userId: actorUserId, activeTo: null, activeFrom: { lte: new Date() } },
        select: { gateId: true }, take: 100,
      })).map((assignment) => assignment.gateId);
      if (!assignedGateIds.length) throw new ForbiddenException('Active gate or management access is required.');
      if (query.gateId && !assignedGateIds.includes(query.gateId)) {
        throw new ForbiddenException('This gate is outside your assignment.');
      }
    }
    const where: Prisma.EstateAccessEventWhereInput = {
      estateId,
      ...(query.gateId ? { gateId: query.gateId } : assignedGateIds ? { gateId: { in: assignedGateIds } } : {}),
      ...(query.eventKind ? { eventKind: query.eventKind } : {}),
      ...(query.from || query.to ? { occurredAt: {
        ...(query.from ? { gte: new Date(query.from) } : {}),
        ...(query.to ? { lte: new Date(query.to) } : {}),
      } } : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.estateAccessEvent.findMany({
        where,
        select: { id: true, estateId: true, gateId: true, propertyId: true, passId: true,
          visitId: true, eventKind: true, reasonCode: true, occurredAt: true, staffUserId: true },
        orderBy: { occurredAt: 'desc' },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.estateAccessEvent.count({ where }),
    ]);
    const propertyIds = [...new Set(items.map((event) => event.propertyId).filter((id): id is string => Boolean(id)))];
    const properties = propertyIds.length
      ? await this.prisma.estateProperty.findMany({
          where: { estateId, id: { in: propertyIds } },
          select: { id: true, code: true, unitNumber: true },
        })
      : [];
    const propertyLabels = new Map(
      properties.map((property) => [property.id, [property.code, property.unitNumber].filter(Boolean).join(' Â· ')]),
    );
    return { items: items.map((event) => ({ id: event.id, estateId: event.estateId, gateId: event.gateId,
      propertyId: event.propertyId, passId: event.passId, visitId: event.visitId,
      eventKind: event.eventKind, reasonCode: event.reasonCode, staffUserId: event.staffUserId,
      occurredAt: event.occurredAt.toISOString(),
      propertyLabel: event.propertyId ? propertyLabels.get(event.propertyId) ?? null : null })),
      total, page: query.page, pageSize: query.pageSize };
  }

  async listSecurityContacts(actorUserId: string, estateId: string) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: { estateId, userId: actorUserId, status: 'ACTIVE', estate: { status: 'ACTIVE' } },
      select: { id: true },
    });
    if (!membership) throw new ForbiddenException('Active estate membership is required.');
    const items = await this.prisma.estateSecurityContact.findMany({
      where: { estateId, active: true },
      select: { id: true, label: true, displayName: true, phoneDisplay: true },
      orderBy: { label: 'asc' }, take: 20,
    });
    return { items };
  }

  async createSecurityContact(actorUserId: string, estateId: string,
    input: { label: string; displayName: string; phoneDisplay: string }) {
    await this.requireManager(actorUserId, estateId);
    const contact = await this.prisma.estateSecurityContact.upsert({
      where: { estateId_label: { estateId, label: input.label.trim() } },
      create: { estateId, label: input.label.trim(), displayName: input.displayName.trim(), phoneDisplay: input.phoneDisplay.trim() },
      update: { displayName: input.displayName.trim(), phoneDisplay: input.phoneDisplay.trim(), active: true },
    });
    await this.prisma.auditEvent.create({ data: { actorUserId, scope: 'estate', estateId,
      action: 'security.contact.upsert', targetType: 'security_contact', targetId: contact.id,
      outcome: 'success', occurredAt: new Date(), metadata: { label: contact.label } } });
    return { id: contact.id, label: contact.label, displayName: contact.displayName, phoneDisplay: contact.phoneDisplay };
  }

  async removeSecurityContact(actorUserId: string, estateId: string, contactId: string) {
    await this.requireManager(actorUserId, estateId);
    const contact = await this.prisma.estateSecurityContact.findFirst({ where: { id: contactId, estateId }, select: { id: true } });
    if (!contact) throw new NotFoundException('Security contact not found.');
    await this.prisma.estateSecurityContact.update({ where: { id: contactId }, data: { active: false } });
    await this.prisma.auditEvent.create({ data: { actorUserId, scope: 'estate', estateId,
      action: 'security.contact.removed', targetType: 'security_contact', targetId: contactId,
      outcome: 'success', occurredAt: new Date() } });
    return { id: contactId, active: false };
  }

  private async resolveAssignedGate(tx: Prisma.TransactionClient, scope: any) {
    const now = new Date();
    const [gate, membership, assignment] = await Promise.all([
      tx.estateGate.findFirst({ where: { id: scope.gateId, estateId: scope.estateId, active: true, estate: { status: 'ACTIVE' } } }),
      tx.estateMembership.findFirst({ where: { estateId: scope.estateId, userId: scope.actorUserId, role: 'SECURITY_OFFICER', status: 'ACTIVE' }, select: { id: true } }),
      tx.estateGateAssignment.findFirst({ where: { estateId: scope.estateId, gateId: scope.gateId, userId: scope.actorUserId, activeTo: null, activeFrom: { lte: now } }, select: { id: true } }),
    ]);
    return { actorUserId: scope.actorUserId, estateId: scope.estateId, gateId: scope.gateId, gate, allowed: Boolean(gate && membership && assignment) };
  }
  private appendGateAccessEvent(tx: Prisma.TransactionClient, event: any) {
    return tx.estateAccessEvent.create({ data: { estateId: event.estateId, passId: event.passId ?? null, visitId: event.visitId ?? null, propertyId: event.propertyId ?? null, gateId: event.gateId, staffUserId: event.staffUserId, eventKind: event.eventKind, reasonCode: event.reasonCode ?? null, occurredAt: new Date(event.occurredAt) } });
  }
  private appendGateAudit(tx: Prisma.TransactionClient, event: any) {
    return tx.auditEvent.create({ data: { actorUserId: event.actorUserId, scope: event.scope, estateId: event.estateId, action: event.action, targetType: event.targetType, targetId: event.targetId, outcome: event.outcome, reason: event.reason ?? null, occurredAt: new Date(event.occurredAt), metadata: { gateId: event.gateId } } });
  }
  private async requireManager(actorUserId: string, estateId: string) {
    const manager = await this.prisma.estateMembership.findFirst({ where: { estateId, userId: actorUserId, role: { in: [...MANAGER_ROLES] }, status: 'ACTIVE', estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!manager) throw new ForbiddenException('Active estate management access is required.');
  }
  private mapGateError(error: unknown): never {
    const code = (error as { code?: string })?.code;
    if (code === 'GATE_ACCESS_DENIED') throw new ForbiddenException('The staff member is not assigned to this gate.');
    if (code === 'ACTIVE_VISIT_NOT_FOUND') throw new NotFoundException('No active visit was found for this gate.');
    if (code === 'INVALID_CREDENTIAL') throw new BadRequestException('This credential cannot be admitted.');
    throw error instanceof Error ? error : new Error('Gate operation failed.');
  }
}

