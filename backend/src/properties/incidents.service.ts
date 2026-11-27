import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PrivateDocumentsService } from '../private-documents/private-documents.service.js';
import { EstateNotificationsService } from './notifications.service.js';
import type { CreateSecurityIncidentDto, ReviewSecurityIncidentDto } from './incidents.dto.js';

const MANAGERS = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER'] as const;
const REVIEWERS = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'SECURITY_OFFICER'] as const;
const STATUS_TO_DB: Record<string, 'REPORTED' | 'ACKNOWLEDGED' | 'INVESTIGATING' | 'RESOLVED' | 'CLOSED'> = {
  reported: 'REPORTED', acknowledged: 'ACKNOWLEDGED', investigating: 'INVESTIGATING', resolved: 'RESOLVED', closed: 'CLOSED',
};

@Injectable()
export class SecurityIncidentsService {
  constructor(private readonly prisma: PrismaService, private readonly privateDocuments: PrivateDocumentsService, private readonly notifications: EstateNotificationsService) {}

  async create(actorId: string, estateId: string, input: CreateSecurityIncidentDto) {
    const observedAt = new Date(input.observedAt);
    if (!Number.isFinite(observedAt.valueOf()) || observedAt > new Date()) throw new BadRequestException('Observed time must be valid and cannot be in the future.');
    const description = input.description.trim();
    if (!description) throw new BadRequestException('Describe what happened before submitting the report.');
    const incidentId = randomUUID();
    const createdAt = new Date();
    const reference = `INC-${incidentId.replaceAll('-', '').slice(0, 10).toUpperCase()}`;
    try {
      return await this.prisma.$transaction(async (tx) => {
        const membership = await tx.estateMembership.findFirst({
          where: { userId: actorId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' } },
          select: { id: true },
        });
        if (!membership) throw new ForbiddenException('Active membership in this estate is required to report an incident.');
        const incident = await tx.estateSecurityIncident.create({ data: {
          id: incidentId, estateId, reference, category: input.category, priority: input.priority, description,
          locationDescription: input.locationDescription?.trim() || null, observedAt, reporterUserId: actorId,
          createdAt, status: 'REPORTED', history: { create: { actorUserId: actorId, fromStatus: null, toStatus: 'REPORTED', occurredAt: createdAt } },
        }, include: { reporter: { select: { displayName: true } }, history: { orderBy: { occurredAt: 'asc' } }, evidence: { orderBy: { uploadedAt: 'asc' } } } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'security_incident.reported', targetType: 'security_incident', targetId: incident.id, outcome: 'success', occurredAt: createdAt } });
        await this.notifications.enqueueRoles(tx, { estateId, roles: [...REVIEWERS], excludeUserId: actorId,
          eventKey: `incident:${incident.id}:reported`, type: 'INCIDENT', title: 'New security incident report',
          message: `${incident.reference} was reported as ${incident.priority.toLowerCase()}.`, sourceId: incident.id });
        return this.view(incident);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2034') throw new ConflictException('Estate access changed while submitting. Reload and try again.');
      throw error;
    }
  }

  async mine(actorId: string, estateId: string) {
    await this.requireMembership(this.prisma, actorId, estateId);
    const items = await this.prisma.estateSecurityIncident.findMany({ where: { estateId, reporterUserId: actorId }, include: { reporter: { select: { displayName: true } }, history: { orderBy: { occurredAt: 'asc' } }, evidence: { orderBy: { uploadedAt: 'asc' } } }, orderBy: { createdAt: 'desc' }, take: 100 });
    return { estateId, items: items.map((item) => this.view(item)) };
  }

  async queue(actorId: string, estateId: string) {
    await this.requireReviewer(this.prisma, actorId, estateId);
    const items = await this.prisma.estateSecurityIncident.findMany({ where: { estateId }, include: { reporter: { select: { displayName: true } }, history: { orderBy: { occurredAt: 'asc' } }, evidence: { orderBy: { uploadedAt: 'asc' } } }, orderBy: { createdAt: 'desc' }, take: 100 });
    return { estateId, items: items.map((item) => this.view(item)) };
  }

  async review(actorId: string, estateId: string, incidentId: string, input: ReviewSecurityIncidentDto) {
    const transitions: Record<string, { from: string[]; to: keyof typeof STATUS_TO_DB; needsNote?: boolean }> = {
      acknowledge: { from: ['reported'], to: 'acknowledged' },
      investigate: { from: ['acknowledged'], to: 'investigating' },
      resolve: { from: ['investigating'], to: 'resolved', needsNote: true },
      close: { from: ['resolved'], to: 'closed', needsNote: true },
    };
    const transition = transitions[input.command];
    if (!transition) throw new BadRequestException('Choose an available incident action.');
    const note = input.note?.trim() ?? '';
    if (transition.needsNote && !note) throw new BadRequestException('Provide a resolution note for this action.');
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireReviewer(tx, actorId, estateId);
        await tx.$queryRaw`SELECT id FROM estate_security_incidents WHERE id = ${incidentId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const incident = await tx.estateSecurityIncident.findFirst({ where: { id: incidentId, estateId }, include: { reporter: { select: { displayName: true } }, history: { orderBy: { occurredAt: 'asc' } }, evidence: { orderBy: { uploadedAt: 'asc' } } } });
        if (!incident) throw new NotFoundException('Incident report not found in this estate.');
        const previous = incident.status.toLowerCase();
        if (!transition.from.includes(previous)) throw new ConflictException('This incident has changed or cannot take that action now.');
        const nextStatus = STATUS_TO_DB[transition.to];
        const now = new Date();
        const updated = await tx.estateSecurityIncident.update({ where: { id: incident.id }, data: {
          status: nextStatus, reviewedByUserId: actorId,
          ...(transition.to === 'resolved' ? { resolutionSummary: note } : {}),
          history: { create: { actorUserId: actorId, fromStatus: incident.status, toStatus: nextStatus, note: note || null, occurredAt: now } },
        }, include: { reporter: { select: { displayName: true } }, history: { orderBy: { occurredAt: 'asc' } }, evidence: { orderBy: { uploadedAt: 'asc' } } } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: `security_incident.${input.command}`, targetType: 'security_incident', targetId: incident.id, outcome: 'success', reason: note || null, occurredAt: now } });
        await this.notifications.enqueueUser(tx, { estateId, recipientUserId: incident.reporterUserId,
          eventKey: `incident:${incident.id}:status:${nextStatus.toLowerCase()}`, type: 'INCIDENT', title: 'Incident report updated',
          message: `Your report ${incident.reference} is now ${nextStatus.toLowerCase().replaceAll('_', ' ')}.`, sourceId: incident.id });
        return this.view(updated);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2034') throw new ConflictException('Incident state changed while reviewing. Reload and try again.');
      throw error;
    }
  }

  async uploadEvidence(actorId: string, estateId: string, incidentId: string, file: Express.Multer.File, idempotencyKey: string | undefined) {
    if (!idempotencyKey || idempotencyKey.length < 8 || idempotencyKey.length > 128) throw new BadRequestException('A valid Idempotency-Key header is required.');
    if (!file?.buffer?.length) throw new BadRequestException('Choose a non-empty PDF, JPEG or PNG file.');
    const detected = this.detectEvidenceType(file.buffer);
    const displayName = this.safeEvidenceName(file.originalname, detected.extension);
    const checksum = this.hash(file.buffer);
    const keyHash = this.hashText(`incident-evidence:v1:${idempotencyKey}`);
    const payloadHash = this.hashText(JSON.stringify({ displayName, contentType: detected.contentType, checksum, byteSize: file.buffer.length }));
    const uniqueWhere = { incidentId_uploadedByUserId_idempotencyKeyHash: { incidentId, uploadedByUserId: actorId, idempotencyKeyHash: keyHash } };
    const existing = await this.prisma.estateSecurityIncidentEvidence.findUnique({ where: uniqueWhere });
    if (existing) {
      if (existing.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was already used for different evidence.');
      await this.requireEvidenceAccess(this.prisma, actorId, estateId, incidentId, false);
      return this.evidenceView(existing, true);
    }
    await this.requireEvidenceAccess(this.prisma, actorId, estateId, incidentId, true);
    const evidenceId = randomUUID();
    const objectKey = await this.privateDocuments.storeIncidentEvidence(incidentId, evidenceId, detected.extension, file.buffer);
    try {
      const result = await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM estate_security_incidents WHERE id = ${incidentId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const locked = await this.requireEvidenceAccess(tx, actorId, estateId, incidentId, true);
        if (locked.status === 'CLOSED') throw new ConflictException('Evidence cannot be added to a closed incident.');
        const uploadedAt = new Date();
        const evidence = await tx.estateSecurityIncidentEvidence.create({ data: {
          id: evidenceId, incidentId, uploadedByUserId: actorId, displayName, objectKey,
          contentType: detected.contentType, byteSize: BigInt(file.buffer.length), checksum,
          idempotencyKeyHash: keyHash, payloadHash, uploadedAt,
        } });
        await tx.auditEvent.create({ data: {
          actorUserId: actorId, scope: 'estate', estateId, action: 'security_incident.evidence_uploaded',
          targetType: 'security_incident_evidence', targetId: evidence.id, outcome: 'success', occurredAt: uploadedAt,
          metadata: { incidentId, contentType: detected.contentType, byteSize: file.buffer.length },
        } });
        return evidence;
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      return this.evidenceView(result, false);
    } catch (error) {
      await this.privateDocuments.remove(objectKey);
      if ((error as { code?: string }).code === 'P2002') {
        const prior = await this.prisma.estateSecurityIncidentEvidence.findUnique({ where: uniqueWhere });
        if (prior?.payloadHash === payloadHash) return this.evidenceView(prior, true);
      }
      throw error;
    }
  }

  async readEvidence(actorId: string, estateId: string, incidentId: string, evidenceId: string) {
    const evidence = await this.prisma.estateSecurityIncidentEvidence.findFirst({
      where: { id: evidenceId, incidentId, incident: { estateId } },
      select: { id: true, objectKey: true, contentType: true, incident: { select: { reporterUserId: true } } },
    });
    if (!evidence) throw new NotFoundException('Incident evidence was not found.');
    if (evidence.incident.reporterUserId === actorId) await this.requireMembership(this.prisma, actorId, estateId);
    else await this.requireReviewer(this.prisma, actorId, estateId);
    const content = await this.privateDocuments.read(evidence.objectKey);
    await this.prisma.auditEvent.create({ data: {
      actorUserId: actorId, scope: 'estate', estateId, action: 'security_incident.evidence_accessed',
      targetType: 'security_incident_evidence', targetId: evidence.id, outcome: 'success', occurredAt: new Date(),
      metadata: { incidentId },
    } });
    return { content, contentType: evidence.contentType, extension: this.extensionFor(evidence.contentType) };
  }

  private async requireEvidenceAccess(db: PrismaService | Prisma.TransactionClient, actorId: string, estateId: string, incidentId: string, requireOpen: boolean) {
    const incident = await db.estateSecurityIncident.findFirst({ where: { id: incidentId, estateId }, select: { id: true, status: true, reporterUserId: true } });
    if (!incident) throw new NotFoundException('Incident report was not found in this estate.');
    if (incident.reporterUserId === actorId) await this.requireMembership(db, actorId, estateId);
    else await this.requireReviewer(db, actorId, estateId);
    if (requireOpen && incident.status === 'CLOSED') throw new ConflictException('Evidence cannot be added to a closed incident.');
    return incident;
  }

  private detectEvidenceType(bytes: Buffer): { contentType: string; extension: 'pdf' | 'jpg' | 'png' } {
    if (bytes.length > 10 * 1024 * 1024) throw new BadRequestException('Evidence files must be 10 MB or smaller.');
    if (bytes.subarray(0, 5).toString('ascii') === '%PDF-') return { contentType: 'application/pdf', extension: 'pdf' };
    if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return { contentType: 'image/png', extension: 'png' };
    if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return { contentType: 'image/jpeg', extension: 'jpg' };
    throw new BadRequestException('Evidence must be a valid PDF, JPEG or PNG file.');
  }

  private safeEvidenceName(value: string, extension: string) {
    const base = value.replace(/\\/g, '/').split('/').pop()?.replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, 160);
    return base || `incident-evidence.${extension}`;
  }

  private hash(bytes: Buffer) { return createHash('sha256').update(bytes).digest('hex'); }
  private hashText(value: string) { return createHash('sha256').update(value, 'utf8').digest('hex'); }
  private extensionFor(contentType: string) { return contentType === 'application/pdf' ? 'pdf' : contentType === 'image/png' ? 'png' : 'jpg'; }
  private evidenceView(evidence: { id: string; incidentId: string; displayName: string; contentType: string; byteSize: bigint; checksum: string; uploadedAt: Date }, replayed: boolean) {
    return { id: evidence.id, incidentId: evidence.incidentId, displayName: evidence.displayName, contentType: evidence.contentType,
      byteSize: Number(evidence.byteSize), checksum: evidence.checksum, uploadedAt: evidence.uploadedAt.toISOString(), replayed };
  }

  private async requireMembership(db: PrismaService | Prisma.TransactionClient, actorId: string, estateId: string) {
    const membership = await db.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active membership in this estate is required.');
  }

  private async requireReviewer(db: PrismaService | Prisma.TransactionClient, actorId: string, estateId: string) {
    const membership = await db.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', role: { in: [...REVIEWERS] }, estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate manager or security officer access is required.');
  }

  private view(item: { id: string; estateId: string; reference: string; category: string; priority: string; description: string; locationDescription: string | null; observedAt: Date; status: string; createdAt: Date; reporter: { displayName: string }; history: { fromStatus: string | null; toStatus: string; occurredAt: Date }[]; evidence: { id: string; incidentId: string; displayName: string; contentType: string; byteSize: bigint; checksum: string; uploadedAt: Date }[] }) {
    return { id: item.id, estateId: item.estateId, reference: item.reference, category: item.category, priority: item.priority,
      description: item.description, locationDescription: item.locationDescription, observedAt: item.observedAt.toISOString(),
      status: item.status.toLowerCase(), reportedAt: item.createdAt.toISOString(), reporterName: item.reporter.displayName,
      statusHistory: item.history.map((entry) => ({ fromStatus: entry.fromStatus?.toLowerCase() ?? null,
        toStatus: entry.toStatus.toLowerCase(), occurredAt: entry.occurredAt.toISOString() })),
      evidence: item.evidence.map((entry) => this.evidenceView(entry, false)) };
  }
}

