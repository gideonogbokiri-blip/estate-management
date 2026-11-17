import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

const SUPER_ADMIN = 'platform_super_admin';
const ACCOUNT_ROLES = ['RESIDENT', 'LANDLORD'] as const;

@Injectable()
export class PlatformMoneyService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(actorUserId: string) {
    await this.requireSuperAdmin(actorUserId);
    const [estates, activeEstates, users, applications, adjustments, credits, debits, roleRows] =
      await this.prisma.$transaction([
        this.prisma.estate.count(),
        this.prisma.estate.count({ where: { status: 'ACTIVE' } }),
        this.prisma.user.count(),
        this.prisma.estateApplication.groupBy({ by: ['status'], orderBy: { status: 'asc' }, _count: { _all: true } }),
        this.prisma.estateAccountAdjustment.count(),
        this.prisma.estateAccountAdjustment.aggregate({ where: { direction: 'credit' }, _sum: { amount: true } }),
        this.prisma.estateAccountAdjustment.aggregate({ where: { direction: 'debit' }, _sum: { amount: true } }),
        this.prisma.estateMembership.groupBy({ by: ['role'], where: { status: 'ACTIVE' }, orderBy: { role: 'asc' }, _count: { _all: true } }),
      ]);
    return {
      estates: { total: estates, active: activeEstates },
      users,
      applications: Object.fromEntries(applications.map((row) => [row.status, (row._count as { _all: number })._all])),
      membershipsByRole: Object.fromEntries(roleRows.map((row) => [row.role, (row._count as { _all: number })._all])),
      adjustments: {
        total: adjustments,
        credited: credits._sum.amount?.toString() ?? '0',
        debited: debits._sum.amount?.toString() ?? '0',
      },
    };
  }

  async accounts(actorUserId: string, estateId: string, query: { search?: string; page: number; pageSize: number }) {
    await this.requireSuperAdmin(actorUserId);
    await this.requireEstate(estateId);
    const search = query.search?.trim();
    const memberships = await this.prisma.estateMembership.findMany({
      where: {
        estateId,
        status: 'ACTIVE',
        role: { in: [...ACCOUNT_ROLES] },
        user: {
          status: 'ACTIVE',
          ...(search ? { OR: [
            { emailNormalized: { contains: search, mode: 'insensitive' } },
            { displayName: { contains: search, mode: 'insensitive' } },
          ] } : {}),
        },
      },
      select: { role: true, user: { select: { id: true, emailNormalized: true, displayName: true, status: true } } },
      orderBy: { user: { displayName: 'asc' } },
      take: 500,
    });
    const userIds = [...new Set(memberships.map((membership) => membership.user.id))];
    const sums = userIds.length
      ? await this.prisma.estateAccountAdjustment.groupBy({
          by: ['accountUserId', 'currency', 'direction'],
          where: { estateId, accountUserId: { in: userIds } },
          orderBy: [{ accountUserId: 'asc' }, { currency: 'asc' }, { direction: 'asc' }],
          _sum: { amount: true },
        })
      : [];
    const balanceByUser = new Map<string, Map<string, string>>();
    for (const row of sums) {
      if (!balanceByUser.has(row.accountUserId)) balanceByUser.set(row.accountUserId, new Map());
      const balances = balanceByUser.get(row.accountUserId)!;
      const amount = new Prisma.Decimal(row._sum.amount?.toString() ?? '0');
      const delta = row.direction === 'credit' ? amount : amount.negated();
      const previous = new Prisma.Decimal(balances.get(row.currency) ?? '0');
      balances.set(row.currency, previous.add(delta).toString());
    }
    const all = memberships.map((membership) => ({
      userId: membership.user.id,
      email: membership.user.emailNormalized,
      displayName: membership.user.displayName,
      accountRole: membership.role,
      balances: Object.fromEntries(balanceByUser.get(membership.user.id) ?? []),
    }));
    const start = (query.page - 1) * query.pageSize;
    return { items: all.slice(start, start + query.pageSize), total: all.length, page: query.page, pageSize: query.pageSize };
  }

  async createAdjustment(actorUserId: string, estateId: string, userId: string,
    input: { amount: string; currency: string; direction: string; reason: string },
    idempotencyKey: string | undefined) {
    await this.requireSuperAdmin(actorUserId);
    if (!idempotencyKey || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new BadRequestException('A valid Idempotency-Key header is required.');
    }
    const amount = new Prisma.Decimal(input.amount);
    if (amount.lte(0) || amount.decimalPlaces() > 2) {
      throw new BadRequestException('Amount must be positive with at most two decimal places.');
    }
    const reason = input.reason.trim();
    if (reason.length < 5) throw new BadRequestException('A reason of at least 5 characters is required.');
    await this.requireEstate(estateId);

    const membership = await this.prisma.estateMembership.findFirst({
      where: { estateId, userId, status: 'ACTIVE', role: { in: [...ACCOUNT_ROLES] }, user: { status: 'ACTIVE' } },
      select: { id: true },
    });
    if (!membership) throw new NotFoundException('An active resident or landlord account was not found in this estate.');

    const hash = (value: string) => createHash('sha256').update(value, 'utf8').digest('hex');
    const keyHash = hash(`balance-adjustment:v1:${idempotencyKey}`);
    const payloadHash = hash(JSON.stringify([estateId, userId, input.amount, input.currency, input.direction, reason]));
    const existing = await this.prisma.estateAccountAdjustment.findUnique({
      where: { createdByUserId_estateId_accountUserId_idempotencyKeyHash: {
        createdByUserId: actorUserId, estateId, accountUserId: userId, idempotencyKeyHash: keyHash,
      } },
    });
    if (existing) {
      if (existing.payloadHash !== payloadHash) {
        throw new ConflictException('This request key was already used for a different adjustment.');
      }
      return { ...existing, replayed: true };
    }

    const now = new Date();
    try {
      const adjustment = await this.prisma.$transaction(async (tx) => {
        const record = await tx.estateAccountAdjustment.create({ data: {
          estateId, accountUserId: userId, amount, currency: input.currency,
          direction: input.direction, reason, createdByUserId: actorUserId,
          idempotencyKeyHash: keyHash, payloadHash, createdAt: now,
        } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'platform', action: `platform.balance.${input.direction}`,
          targetType: 'estate_account_adjustment', targetId: record.id,
          outcome: 'success', occurredAt: now,
          metadata: { estateId, accountUserId: userId, amount: input.amount, currency: input.currency, reason },
        } });
        return record;
      });
      return { ...adjustment, replayed: false };
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') {
        throw new ConflictException('The adjustment changed concurrently. Retry with the same request key.');
      }
      throw error;
    }
  }

  async adjustments(actorUserId: string, estateId: string, userId: string,
    query: { page: number; pageSize: number }) {
    await this.requireSuperAdmin(actorUserId);
    await this.requireEstate(estateId);
    const [items, total] = await this.prisma.$transaction([
      this.prisma.estateAccountAdjustment.findMany({
        where: { estateId, accountUserId: userId },
        orderBy: { createdAt: 'desc' },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.estateAccountAdjustment.count({ where: { estateId, accountUserId: userId } }),
    ]);
    return { items: items.map((item) => ({ ...item, amount: item.amount.toString() })), total, page: query.page, pageSize: query.pageSize };
  }

  private async requireEstate(estateId: string) {
    const estate = await this.prisma.estate.findFirst({ where: { id: estateId }, select: { id: true } });
    if (!estate) throw new NotFoundException('Estate not found.');
  }

  private async requireSuperAdmin(actorUserId: string) {
    const grant = await this.prisma.platformRoleGrant.findUnique({
      where: { userId_roleKey: { userId: actorUserId, roleKey: SUPER_ADMIN } },
      select: { id: true },
    });
    if (!grant) throw new ForbiddenException('Only a platform super administrator can manage account balances.');
  }
}
