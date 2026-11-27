import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateEstateAnnouncementDto } from './announcements.dto.js';

const STAFF_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER'] as const;

@Injectable()
export class EstateAnnouncementsService {
  constructor(private readonly prisma: PrismaService) {}

  async listForStaff(actorUserId: string, estateId: string) {
    await this.requireStaff(actorUserId, estateId);
    const rows = await this.prisma.estateAnnouncement.findMany({
      where: { estateId }, orderBy: [{ createdAt: 'desc' }], take: 100,
      select: { id: true, estateId: true, title: true, body: true, priority: true, audience: true, status: true, publishedAt: true, createdAt: true },
    });
    return { items: rows.map((row) => this.view(row)) };
  }

  async createDraft(actorUserId: string, estateId: string, input: CreateEstateAnnouncementDto) {
    const title = input.title.trim();
    const body = input.body.trim();
    if (title.length < 3 || !body) throw new ConflictException('Add an announcement title and message.');
    return this.prisma.$transaction(async (tx) => {
      const membership = await this.requireStaff(actorUserId, estateId, tx);
      if (input.priority === 'emergency' && membership.role !== 'ESTATE_ADMINISTRATOR') {
        throw new ForbiddenException('Emergency announcements require estate administrator access.');
      }
      const row = await tx.estateAnnouncement.create({ data: {
        estateId, title, body, priority: input.priority.toUpperCase() as 'NORMAL' | 'EMERGENCY',
        audience: 'ALL_RESIDENTS', createdById: actorUserId,
      } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'estate_announcement.draft_created', targetType: 'estate_announcement', targetId: row.id,
        outcome: 'success', occurredAt: row.createdAt, metadata: { priority: row.priority.toLowerCase(), audience: row.audience },
      } });
      return this.view(row);
    });
  }

  async publish(actorUserId: string, estateId: string, announcementId: string) {
    return this.prisma.$transaction(async (tx) => {
      const membership = await this.requireStaff(actorUserId, estateId, tx);
      await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_announcements WHERE id = ${announcementId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
      const row = await tx.estateAnnouncement.findFirst({ where: { id: announcementId, estateId } });
      if (!row) throw new NotFoundException('Announcement not found in this estate.');
      if (row.status !== 'DRAFT') throw new ConflictException('Only a draft announcement can be published.');
      if (row.priority === 'EMERGENCY' && membership.role !== 'ESTATE_ADMINISTRATOR') {
        throw new ForbiddenException('Emergency announcements require estate administrator access.');
      }
      const publishedAt = new Date();
      const updated = await tx.estateAnnouncement.update({ where: { id: row.id }, data: { status: 'PUBLISHED', publishedAt } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'estate_announcement.published', targetType: 'estate_announcement', targetId: row.id,
        outcome: 'success', occurredAt: publishedAt, metadata: { priority: row.priority.toLowerCase(), audience: row.audience },
      } });
      return this.view(updated);
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }).catch((error: unknown) => {
      if (typeof error === 'object' && error !== null && 'code' in error && (error as { code?: unknown }).code === 'P2034') {
        throw new ConflictException('Announcement changed while publishing. Reload and try again.');
      }
      throw error;
    });
  }

  async listMine(actorUserId: string) {
    const rows = await this.prisma.estateAnnouncement.findMany({
      where: {
        status: 'PUBLISHED', estate: { is: { status: 'ACTIVE', memberships: { some: { userId: actorUserId, status: 'ACTIVE', role: { in: ['RESIDENT', 'LANDLORD'] } } } } },
      },
      orderBy: [{ publishedAt: 'desc' }], take: 100,
      include: { estate: { select: { id: true, name: true } }, reads: { where: { userId: actorUserId }, select: { id: true } } },
    });
    return { items: rows.map((row) => ({ ...this.view(row), estateName: row.estate.name, read: row.reads.length > 0 })) };
  }

  async markRead(actorUserId: string, announcementId: string) {
    try {
      await this.prisma.$transaction(async (tx) => {
        const row = await tx.estateAnnouncement.findFirst({
          where: { id: announcementId, status: 'PUBLISHED', estate: { is: { status: 'ACTIVE', memberships: { some: { userId: actorUserId, status: 'ACTIVE', role: { in: ['RESIDENT', 'LANDLORD'] } } } } } },
          select: { id: true, estateId: true },
        });
        if (!row) throw new NotFoundException('Announcement not found.');
        const existing = await tx.estateAnnouncementRead.findUnique({ where: { announcementId_userId: { announcementId, userId: actorUserId } }, select: { id: true } });
        if (existing) return;
        const readAt = new Date();
        await tx.estateAnnouncementRead.create({ data: { announcementId, userId: actorUserId, readAt } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId: row.estateId, action: 'estate_announcement.read', targetType: 'estate_announcement', targetId: announcementId,
          outcome: 'success', occurredAt: readAt,
        } });
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (typeof error === 'object' && error !== null && 'code' in error && (error as { code?: unknown }).code === 'P2002') return { read: true };
      throw error;
    }
    return { read: true };
  }

  private async requireStaff(actorUserId: string, estateId: string, tx: Prisma.TransactionClient | PrismaService = this.prisma) {
    const membership = await tx.estateMembership.findFirst({
      where: { userId: actorUserId, estateId, status: 'ACTIVE', role: { in: [...STAFF_ROLES] }, estate: { status: 'ACTIVE' } },
      select: { role: true },
    });
    if (!membership) throw new ForbiddenException('Active estate announcement management access is required.');
    return membership;
  }

  private view(row: { id: string; estateId: string; title: string; body: string; priority: string; audience: string; status: string; publishedAt: Date | null; createdAt: Date }) {
    return {
      id: row.id, estateId: row.estateId, title: row.title, body: row.body,
      category: row.priority.toLowerCase(), emergency: row.priority === 'EMERGENCY',
      audience: row.audience.toLowerCase(), audienceLabel: 'All residents and landlords',
      status: row.status.toLowerCase(), publishedAt: row.publishedAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
    };
  }
}

