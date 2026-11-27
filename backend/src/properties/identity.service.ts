import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, type EstateRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { DecideIdentityVerificationDto, SubmitIdentityVerificationDto } from './identity.dto.js';

const MANAGEMENT_ROLES: EstateRole[] = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'FINANCE_MANAGER'];

@Injectable()
export class IdentityService {
  constructor(private readonly prisma: PrismaService) {}

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
      id: row.id, estateId: row.estateId, userId: row.userId,
      method: row.method, provider: row.provider, providerReference: row.providerReference,
      level: row.level, status: row.status.toLowerCase(),
      demo: row.method === 'DEMO_DECLARATION',
      consentGiven: row.consentGiven, consentAt: row.consentAt.toISOString(),
      decidedById: row.decidedById, decisionReason: row.decisionReason,
      decidedAt: row.decidedAt?.toISOString() ?? null,
      submittedAt: row.submittedAt.toISOString(),
    };
  }

  async submit(actorUserId: string, estateId: string, input: SubmitIdentityVerificationDto) {
    await this.membership(actorUserId, estateId);
    if (input.consentGiven !== true) throw new BadRequestException('Explicit consent is required before identity verification.');
    let providerReference = input.providerReference?.trim() || null;
    if (input.method === 'DEMO_DECLARATION') {
      if (!providerReference) providerReference = `DEMO-ID-${actorUserId.slice(0, 8).toUpperCase()}`;
      if (!providerReference.startsWith('DEMO-')) providerReference = `DEMO-${providerReference}`;
    } else if (!providerReference) {
      throw new BadRequestException('A provider verification reference is required for this method.');
    }
    const pending = await this.prisma.identityVerification.findFirst({
      where: { estateId, userId: actorUserId, status: 'PENDING' }, select: { id: true },
    });
    if (pending) throw new ConflictException('You already have a pending identity verification in this estate.');
    const row = await this.prisma.identityVerification.create({ data: {
      estateId, userId: actorUserId, method: input.method, provider: input.provider.trim(),
      providerReference, level: input.level, consentGiven: true, consentAt: new Date(), status: 'PENDING',
    } });
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'estate', estateId, action: 'identity.verification_submitted',
      targetType: 'identity_verification', targetId: row.id, outcome: 'success', occurredAt: new Date(),
      metadata: { method: input.method, provider: input.provider, demo: input.method === 'DEMO_DECLARATION' },
    } });
    return this.view(row);
  }

  async listMine(actorUserId: string, estateId: string) {
    await this.membership(actorUserId, estateId);
    const rows = await this.prisma.identityVerification.findMany({
      where: { estateId, userId: actorUserId }, orderBy: { submittedAt: 'desc' }, take: 50,
    });
    return { items: rows.map((row) => this.view(row)) };
  }

  async listForEstate(actorUserId: string, estateId: string) {
    await this.membership(actorUserId, estateId, true);
    const rows = await this.prisma.identityVerification.findMany({
      where: { estateId }, orderBy: [{ status: 'asc' }, { submittedAt: 'desc' }], take: 200,
    });
    const userIds = [...new Set(rows.map((row) => row.userId))];
    const users = await this.prisma.user.findMany({ where: { id: { in: userIds } }, select: { id: true, displayName: true, emailNormalized: true } });
    const names = new Map(users.map((user) => [user.id, user]));
    return { items: rows.map((row) => ({
      ...this.view(row),
      userName: names.get(row.userId)?.displayName ?? 'Resident',
      userEmail: names.get(row.userId)?.emailNormalized ?? '',
    })) };
  }

  async decide(actorUserId: string, estateId: string, verificationId: string, input: DecideIdentityVerificationDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.membership(actorUserId, estateId, true);
        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM identity_verifications WHERE id = ${verificationId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const row = await tx.identityVerification.findFirst({ where: { id: verificationId, estateId }, select: { id: true, status: true, method: true } });
        if (!row) throw new NotFoundException('Identity verification not found.');
        if (row.status !== 'PENDING') throw new ConflictException('Only a pending identity verification can be decided.');
        if (input.decision === 'reject' && !input.reason?.trim()) {
          throw new BadRequestException('A reason is required when rejecting an identity verification.');
        }
        const updated = await tx.identityVerification.update({ where: { id: verificationId }, data: {
          status: input.decision === 'verify' ? 'VERIFIED' : 'REJECTED',
          decidedById: actorUserId, decidedAt: new Date(), decisionReason: input.reason?.trim() || null,
        } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId,
          action: input.decision === 'verify' ? 'identity.verification_verified' : 'identity.verification_rejected',
          targetType: 'identity_verification', targetId: verificationId, outcome: 'success', occurredAt: new Date(),
          metadata: { decision: input.decision, method: row.method, demo: row.method === 'DEMO_DECLARATION' },
        } });
        return this.view(updated);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (['P2002', 'P2034'].includes((error as { code?: string })?.code ?? '')) {
        throw new ConflictException('This verification changed during review. Reload and try again.');
      }
      throw error;
    }
  }
}

