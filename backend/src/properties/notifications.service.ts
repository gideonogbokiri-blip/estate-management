import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class EstateNotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async enqueueRoles(
    tx: Prisma.TransactionClient,
    input: { estateId: string; roles: string[]; excludeUserId?: string; eventKey: string; type: 'EXPENSE' | 'INCIDENT'; title: string; message: string; sourceId: string },
  ) {
    const members = await tx.estateMembership.findMany({
      where: { estateId: input.estateId, status: 'ACTIVE', role: { in: input.roles as never }, user: { status: 'ACTIVE' }, estate: { status: 'ACTIVE' }, ...(input.excludeUserId ? { userId: { not: input.excludeUserId } } : {}) },
      select: { userId: true },
    });
    if (!members.length) return;
    const users = await tx.user.findMany({
      where: { id: { in: members.map((member) => member.userId) } },
      select: { id: true, emailNormalized: true },
    });
    const emails = new Map(users.map((user) => [user.id, user.emailNormalized]));
    for (const { userId } of members) {
      let created;
      try {
        created = await tx.estateNotification.create({ data: {
          estateId: input.estateId, recipientUserId: userId, eventKey: input.eventKey,
          type: input.type, title: input.title, message: input.message, sourceId: input.sourceId,
        }, select: { id: true } });
      } catch (error) {
        if ((error as { code?: string }).code === 'P2002') continue;
        throw error;
      }
      const email = emails.get(userId);
      if (email) {
        await tx.estateNotificationDelivery.create({ data: {
          notificationId: created.id, estateId: input.estateId, recipientUserId: userId,
          recipientEmail: email, channel: 'email', status: 'pending',
        } });
      }
    }
  }

  async enqueueUser(
    tx: Prisma.TransactionClient,
    input: { estateId: string; recipientUserId: string; eventKey: string; type: 'EXPENSE' | 'INCIDENT'; title: string; message: string; sourceId: string },
  ) {
    const user = await tx.user.findUnique({
      where: { id: input.recipientUserId },
      select: { emailNormalized: true },
    });
    let created;
    try {
      created = await tx.estateNotification.create({ data: { ...input }, select: { id: true } });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') return;
      throw error;
    }
    await tx.estateNotificationDelivery.create({ data: {
      notificationId: created.id, estateId: input.estateId, recipientUserId: input.recipientUserId,
      recipientEmail: user?.emailNormalized ?? '', channel: 'email', status: 'pending',
    } });
  }

  async listMine(userId: string) {
    const rows = await this.prisma.estateNotification.findMany({
      where: { recipientUserId: userId, estate: { is: { status: 'ACTIVE', memberships: { some: { userId, status: 'ACTIVE' } } } } },
      orderBy: [{ readAt: 'asc' }, { createdAt: 'desc' }], take: 100,
      include: { estate: { select: { name: true } } },
    });
    return { unreadCount: rows.filter((row) => row.readAt === null).length, items: rows.map((row) => this.view(row)) };
  }

  async markAllRead(userId: string) {
    const now = new Date();
    const result = await this.prisma.estateNotification.updateMany({
      where: {
        recipientUserId: userId,
        readAt: null,
        estate: { is: { status: 'ACTIVE', memberships: { some: { userId, status: 'ACTIVE' } } } },
      },
      data: { readAt: now },
    });
    return { marked: result.count, readAt: now.toISOString() };
  }

  async markRead(userId: string, notificationId: string) {
    const row = await this.prisma.estateNotification.findFirst({
      where: { id: notificationId, recipientUserId: userId, estate: { is: { status: 'ACTIVE', memberships: { some: { userId, status: 'ACTIVE' } } } } },
      select: { id: true, readAt: true },
    });
    if (!row) throw new NotFoundException('Notification not found.');
    if (row.readAt) return { read: true, readAt: row.readAt.toISOString() };
    const readAt = new Date();
    await this.prisma.estateNotification.updateMany({ where: { id: row.id, recipientUserId: userId, readAt: null }, data: { readAt } });
    return { read: true, readAt: readAt.toISOString() };
  }

  private view(row: { id: string; estateId: string; type: string; title: string; message: string; sourceId: string; createdAt: Date; readAt: Date | null; estate: { name: string } }) {
    return { id: row.id, estateId: row.estateId, estateName: row.estate.name, type: row.type.toLowerCase(), title: row.title,
      message: row.message, sourceId: row.sourceId, createdAt: row.createdAt.toISOString(), readAt: row.readAt?.toISOString() ?? null };
  }
}
