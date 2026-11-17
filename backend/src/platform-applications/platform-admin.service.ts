import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

const SUPER_ADMIN = 'platform_super_admin';
const REVIEWER = 'platform_application_reviewer';
const ASSIGNABLE_ROLES = [SUPER_ADMIN, REVIEWER] as const;

@Injectable()
export class PlatformAdminService {
  constructor(private readonly prisma: PrismaService) {}

  async team(actorUserId: string) {
    await this.requireReviewer(actorUserId);
    const grants = await this.prisma.platformRoleGrant.findMany({
      orderBy: [{ roleKey: 'asc' }, { createdAt: 'asc' }],
      select: { userId: true, roleKey: true, createdAt: true },
      take: 500,
    });
    const users = await this.prisma.user.findMany({
      where: { id: { in: [...new Set(grants.map((grant) => grant.userId))] } },
      select: { id: true, emailNormalized: true, displayName: true, status: true },
      orderBy: { displayName: 'asc' },
    });
    return {
      items: users.map((user) => ({
        userId: user.id,
        email: user.emailNormalized,
        displayName: user.displayName,
        accountStatus: user.status,
        roles: grants
          .filter((grant) => grant.userId === user.id)
          .map((grant) => grant.roleKey),
      })),
    };
  }

  async candidateUsers(actorUserId: string, search: string) {
    await this.requireSuperAdmin(actorUserId);
    const term = search?.trim();
    const users = await this.prisma.user.findMany({
      where: {
        status: 'ACTIVE',
        ...(term ? { OR: [
          { emailNormalized: { contains: term, mode: 'insensitive' } },
          { displayName: { contains: term, mode: 'insensitive' } },
        ] } : {}),
      },
      select: { id: true, emailNormalized: true, displayName: true },
      orderBy: { displayName: 'asc' },
      take: 20,
    });
    return { items: users.map((user) => ({ userId: user.id, email: user.emailNormalized, displayName: user.displayName })) };
  }

  async grantRole(actorUserId: string, targetUserId: string, roleKey: string) {
    await this.requireSuperAdmin(actorUserId);
    if (!(ASSIGNABLE_ROLES as readonly string[]).includes(roleKey)) {
      throw new BadRequestException('Unsupported platform role.');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, status: true, emailNormalized: true },
    });
    if (!user) throw new NotFoundException('Account not found.');
    if (user.status !== 'ACTIVE') throw new BadRequestException('Only active accounts can hold platform roles.');
    const grant = await this.prisma.platformRoleGrant.upsert({
      where: { userId_roleKey: { userId: targetUserId, roleKey } },
      update: {},
      create: { userId: targetUserId, roleKey, grantedById: actorUserId },
    });
    await this.audit(actorUserId, 'platform.role.granted', grant.id, { roleKey, targetUserId, email: user.emailNormalized });
    return { userId: targetUserId, roleKey, granted: true };
  }

  async revokeRole(actorUserId: string, targetUserId: string, roleKey: string) {
    await this.requireSuperAdmin(actorUserId);
    if (!(ASSIGNABLE_ROLES as readonly string[]).includes(roleKey)) {
      throw new BadRequestException('Unsupported platform role.');
    }
    if (actorUserId === targetUserId && roleKey === SUPER_ADMIN) {
      throw new BadRequestException('You cannot revoke your own platform super administrator role.');
    }
    const grant = await this.prisma.platformRoleGrant.findUnique({
      where: { userId_roleKey: { userId: targetUserId, roleKey } },
      select: { id: true },
    });
    if (!grant) throw new NotFoundException('Platform role grant not found.');
    if (roleKey === SUPER_ADMIN) {
      const remaining = await this.prisma.platformRoleGrant.count({ where: { roleKey: SUPER_ADMIN } });
      if (remaining <= 1) throw new BadRequestException('At least one platform super administrator must remain.');
    }
    await this.prisma.platformRoleGrant.delete({ where: { id: grant.id } });
    await this.audit(actorUserId, 'platform.role.revoked', grant.id, { roleKey, targetUserId });
    return { userId: targetUserId, roleKey, revoked: true };
  }

  async estates(actorUserId: string, query: { search?: string; status?: string; page: number; pageSize: number }) {
    await this.requireReviewer(actorUserId);
    const search = query.search?.trim();
    const where: Prisma.EstateWhereInput = {
      ...(query.status ? { status: query.status as Prisma.EnumEstateStatusFilter['equals'] } : {}),
      ...(search ? { OR: [
        { name: { contains: search, mode: 'insensitive' } },
        { estateCode: { contains: search, mode: 'insensitive' } },
        { state: { contains: search, mode: 'insensitive' } },
      ] } : {}),
    };
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.estate.findMany({
        where,
        select: {
          id: true, estateCode: true, name: true, estateType: true, address: true,
          state: true, status: true, activatedAt: true,
          _count: { select: { memberships: true, properties: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.estate.count({ where }),
    ]);
    return {
      items: rows.map((estate) => ({
        id: estate.id,
        estateCode: estate.estateCode,
        name: estate.name,
        estateType: estate.estateType,
        address: estate.address,
        state: estate.state,
        status: estate.status,
        activatedAt: estate.activatedAt.toISOString(),
        memberCount: estate._count.memberships,
        propertyCount: estate._count.properties,
      })),
      total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  private async requireReviewer(actorUserId: string) {
    const grants = await this.prisma.platformRoleGrant.findMany({
      where: { userId: actorUserId, roleKey: { in: [REVIEWER, SUPER_ADMIN] } },
      select: { roleKey: true },
    });
    if (!grants.length) throw new ForbiddenException('Platform reviewer permission is required.');
    return grants.map((grant) => grant.roleKey);
  }

  private async requireSuperAdmin(actorUserId: string) {
    const grant = await this.prisma.platformRoleGrant.findUnique({
      where: { userId_roleKey: { userId: actorUserId, roleKey: SUPER_ADMIN } },
      select: { id: true },
    });
    if (!grant) throw new ForbiddenException('Only a platform super administrator can manage platform access.');
  }

  private async audit(actorUserId: string, action: string, targetId: string, metadata: Prisma.InputJsonObject) {
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'platform', action, targetType: 'platform_role_grant', targetId,
      outcome: 'success', occurredAt: new Date(), metadata,
    } });
  }
}
