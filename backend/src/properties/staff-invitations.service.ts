import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateStaffInvitationDto } from './staff-invitations.dto.js';

const ADMIN = 'ESTATE_ADMINISTRATOR' as const;
const hash = (value: string) => createHash('sha256').update(value, 'utf8').digest('hex');
const EXPIRY_MS = 7 * 24 * 60 * 60 * 1000;

@Injectable()
export class StaffInvitationsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(actorId: string, estateId: string) {
    await this.requireAdministrator(this.prisma, actorId, estateId);
    const now = new Date();
    await this.prisma.estateStaffInvitation.updateMany({ where: { estateId, status: 'PENDING', expiresAt: { lte: now } }, data: { status: 'EXPIRED' } });
    const items = await this.prisma.estateStaffInvitation.findMany({ where: { estateId }, include: { createdBy: { select: { displayName: true } } }, orderBy: { createdAt: 'desc' }, take: 100 });
    return { estateId, items: items.map((item) => ({ id: item.id, email: item.emailNormalized, role: item.role.toLowerCase(), status: item.status.toLowerCase(),
      createdBy: item.createdBy.displayName, createdAt: item.createdAt.toISOString(), expiresAt: item.expiresAt.toISOString(), acceptedAt: item.acceptedAt?.toISOString() ?? null })) };
  }

  async create(actorId: string, estateId: string, input: CreateStaffInvitationDto) {
    const email = input.email.trim().toLowerCase();
    const token = randomBytes(32).toString('base64url');
    const now = new Date();
    const expiresAt = new Date(now.getTime() + EXPIRY_MS);
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireAdministrator(tx, actorId, estateId);
        const existingRole = await tx.estateMembership.findFirst({ where: { estateId, role: input.role, user: { emailNormalized: email } }, select: { id: true } });
        if (existingRole) throw new ConflictException('This account already has a record for that estate role. Restore existing access through the estate access controls instead.');
        const existing = await tx.estateStaffInvitation.findFirst({ where: { estateId, emailNormalized: email, role: input.role, status: 'PENDING', expiresAt: { gt: now } }, select: { id: true } });
        if (existing) throw new ConflictException('A pending invitation already exists for this account and role.');
        const record = await tx.estateStaffInvitation.create({ data: { estateId, emailNormalized: email, role: input.role, tokenHash: hash(token), createdById: actorId, expiresAt } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'estate_staff_invitation.created', targetType: 'estate_staff_invitation', targetId: record.id, outcome: 'success', occurredAt: now, metadata: { email, role: input.role, expiresAt: expiresAt.toISOString() } } });
        return { id: record.id, estateId, email, role: input.role.toLowerCase(), status: 'pending', expiresAt: expiresAt.toISOString(), invitationCode: token,
          notice: 'Share this code privately. It is shown once and expires in seven days. The invited person must sign in with this email to accept.' };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2034') throw new ConflictException('Invitation state changed while saving. Reload and try again.');
      throw error;
    }
  }

  async accept(actorId: string, estateId: string, token: string) {
    const tokenHash = hash(token);
    const now = new Date();
    try {
      return await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM estate_staff_invitations WHERE token_hash = ${tokenHash} AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const invitation = await tx.estateStaffInvitation.findFirst({ where: { tokenHash, estateId }, include: { estate: { select: { status: true, name: true } } } });
        if (!invitation || invitation.status !== 'PENDING') throw new NotFoundException('This invitation is invalid, used or revoked.');
        if (invitation.expiresAt <= now) throw new ConflictException('This invitation has expired. Ask an estate administrator for a new code.');
        if (invitation.estate.status !== 'ACTIVE') throw new ConflictException('This estate is not active.');
        const user = await tx.user.findUnique({ where: { id: actorId }, select: { id: true, emailNormalized: true } });
        if (!user || user.emailNormalized !== invitation.emailNormalized) throw new ForbiddenException('Sign in with the email address the administrator invited.');
        const existingMembership = await tx.estateMembership.findUnique({ where: { estateId_userId_role: { estateId, userId: actorId, role: invitation.role } }, select: { status: true } });
        if (existingMembership && existingMembership.status !== 'ACTIVE') {
          throw new ConflictException('This role was previously suspended or revoked. Ask an administrator to restore the existing access record.');
        }
        if (!existingMembership) await tx.estateMembership.create({ data: { estateId, userId: actorId, role: invitation.role, status: 'ACTIVE' } });
        await tx.estateStaffInvitation.update({ where: { id: invitation.id }, data: { status: 'ACCEPTED', acceptedById: actorId, acceptedAt: now } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'estate_staff_invitation.accepted', targetType: 'estate_staff_invitation', targetId: invitation.id, outcome: 'success', occurredAt: now, metadata: { role: invitation.role } } });
        return { estateId, estateName: invitation.estate.name, role: invitation.role.toLowerCase(), status: 'accepted' };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2034') throw new ConflictException('Invitation state changed while accepting. Ask an administrator to check its status.');
      throw error;
    }
  }

  async revoke(actorId: string, estateId: string, invitationId: string) {
    return this.prisma.$transaction(async (tx) => {
      await this.requireAdministrator(tx, actorId, estateId);
      const invitation = await tx.estateStaffInvitation.findFirst({ where: { id: invitationId, estateId } });
      if (!invitation) throw new NotFoundException('Invitation not found in this estate.');
      if (invitation.status !== 'PENDING') throw new ConflictException('Only a pending invitation can be revoked.');
      const now = new Date();
      await tx.estateStaffInvitation.update({ where: { id: invitation.id }, data: { status: 'REVOKED', revokedAt: now } });
      await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'estate_staff_invitation.revoked', targetType: 'estate_staff_invitation', targetId: invitation.id, outcome: 'success', occurredAt: now } });
      return { id: invitation.id, status: 'revoked' };
    });
  }

  private async requireAdministrator(db: PrismaService | Prisma.TransactionClient, actorId: string, estateId: string) {
    const membership = await db.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', role: ADMIN, estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate administrator access is required to manage staff invitations.');
  }
}

