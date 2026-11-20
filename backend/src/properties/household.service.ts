import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, type EstateRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AddHouseholdMemberDto, DecideHouseholdMemberDto, EndHouseholdMemberDto } from './household.dto.js';

const MANAGEMENT_ROLES: EstateRole[] = ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER', 'FINANCE_MANAGER'];
const ACTIVE_STATUSES = ['ACTIVE', 'PENDING_APPROVAL'];

@Injectable()
export class HouseholdService {
  constructor(private readonly prisma: PrismaService) {}

  private date(value: string) { return new Date(`${value}T00:00:00.000Z`); }
  private day(value: Date) { return value.toISOString().slice(0, 10); }

  private businessToday() {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Africa/Lagos', year: 'numeric', month: '2-digit', day: '2-digit',
    }).formatToParts(new Date());
    const part = (type: string) => parts.find((item) => item.type === type)?.value ?? '';
    return `${part('year')}-${part('month')}-${part('day')}`;
  }

  private async membership(actorUserId: string, estateId: string, managementOnly = false) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: {
        userId: actorUserId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' },
        ...(managementOnly ? { role: { in: MANAGEMENT_ROLES } } : {}),
      },
      select: { role: true },
    });
    if (!membership) {
      throw new ForbiddenException(managementOnly
        ? 'Active estate management access is required.'
        : 'Active estate membership is required.');
    }
    return membership;
  }

  private async hasPropertyRelationship(estateId: string, propertyId: string, userId: string, from: Date, to: Date | null) {
    const window = { estateId, propertyId, status: 'ACTIVE' as const, effectiveFrom: { lte: to ?? new Date('9999-12-31T00:00:00.000Z') }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: from } }] };
    const [occupancy, tenancy, ownership] = await Promise.all([
      this.prisma.propertyOccupancy.findFirst({ where: { ...window, residentId: userId }, select: { id: true } }),
      this.prisma.estateTenancy.findFirst({ where: { ...window, tenantUserId: userId }, select: { id: true } }),
      this.prisma.estateOwnershipInterest.findFirst({ where: { ...window, ownerUserId: userId, verificationStatus: 'VERIFIED' }, select: { id: true } }),
    ]);
    return Boolean(occupancy || tenancy || ownership);
  }

  private async decorate(rows: any[]) {
    if (rows.length === 0) return [];
    const userIds = new Set<string>();
    const propertyIds = new Set<string>();
    for (const row of rows) {
      userIds.add(row.primaryUserId);
      userIds.add(row.addedById);
      if (row.decidedById) userIds.add(row.decidedById);
      if (row.linkedUserId) userIds.add(row.linkedUserId);
      propertyIds.add(row.propertyId);
      propertyIds.add(row.estateId);
    }
    const [users, properties, estates] = await Promise.all([
      this.prisma.user.findMany({ where: { id: { in: [...userIds] } }, select: { id: true, displayName: true, emailNormalized: true } }),
      this.prisma.estateProperty.findMany({ where: { id: { in: [...propertyIds] } }, select: { id: true, code: true, unitNumber: true } }),
      this.prisma.estate.findMany({ where: { id: { in: [...propertyIds] } }, select: { id: true, name: true } }),
    ]);
    const userName = new Map(users.map((item) => [item.id, item]));
    const propertyCode = new Map(properties.map((item) => [item.id, item.code]));
    const propertyUnit = new Map(properties.map((item) => [item.id, item.unitNumber]));
    const estateName = new Map(estates.map((item) => [item.id, item.name]));
    return rows.map((row) => ({
      id: row.id, estateId: row.estateId, estateName: estateName.get(row.estateId) ?? '',
      propertyId: row.propertyId, propertyCode: propertyCode.get(row.propertyId) ?? '',
      propertyUnit: propertyUnit.get(row.propertyId) ?? null,
      primaryUserId: row.primaryUserId, primaryUserName: userName.get(row.primaryUserId)?.displayName ?? 'Resident',
      fullName: row.fullName, relationship: row.relationship, memberType: row.memberType,
      dateOfBirth: row.dateOfBirth ? this.day(row.dateOfBirth) : null,
      phone: row.phone, email: row.email, linkedUserId: row.linkedUserId,
      financialAccess: row.financialAccess, status: row.status.toLowerCase(),
      effectiveFrom: this.day(row.effectiveFrom), effectiveTo: row.effectiveTo ? this.day(row.effectiveTo) : null,
      addedByName: userName.get(row.addedById)?.displayName ?? '',
      decidedByName: row.decidedById ? userName.get(row.decidedById)?.displayName ?? '' : null,
      decisionReason: row.decisionReason,
      createdAt: row.createdAt.toISOString(),
    }));
  }

  async listForEstate(actorUserId: string, estateId: string, filters: { propertyId?: string; status?: string; primaryUserId?: string }) {
    await this.membership(actorUserId, estateId, true);
    const where: Prisma.HouseholdMemberWhereInput = { estateId };
    if (filters.propertyId) where.propertyId = filters.propertyId;
    if (filters.status) where.status = filters.status.toUpperCase();
    if (filters.primaryUserId) where.primaryUserId = filters.primaryUserId;
    const rows = await this.prisma.householdMember.findMany({
      where, orderBy: [{ effectiveFrom: 'desc' }, { createdAt: 'desc' }], take: 300,
    });
    return { items: await this.decorate(rows) };
  }

  async listMine(actorUserId: string) {
    const [activeEstates, activeProperties] = await Promise.all([
      this.prisma.estate.findMany({ where: { status: 'ACTIVE' }, select: { id: true } }),
      this.prisma.estateProperty.findMany({ where: { status: { not: 'ARCHIVED' } }, select: { id: true } }),
    ]);
    const rows = await this.prisma.householdMember.findMany({
      where: {
        OR: [{ primaryUserId: actorUserId }, { linkedUserId: actorUserId }],
        estateId: { in: activeEstates.map((item) => item.id) },
        propertyId: { in: activeProperties.map((item) => item.id) },
      },
      orderBy: [{ effectiveFrom: 'desc' }], take: 200,
    });
    return { items: await this.decorate(rows) };
  }

  async add(actorUserId: string, estateId: string, input: AddHouseholdMemberDto) {
    const membership = await this.membership(actorUserId, estateId);
    const isManager = MANAGEMENT_ROLES.includes(membership.role);
    const primaryUserId = isManager ? input.primaryUserId : actorUserId;
    if (!primaryUserId) throw new BadRequestException('Select the resident whose household this member belongs to.');

    const from = this.date(input.effectiveFrom);
    const to = input.effectiveTo ? this.date(input.effectiveTo) : null;
    if (this.day(from) !== input.effectiveFrom || (to && this.day(to) !== input.effectiveTo)) {
      throw new BadRequestException('Provide valid calendar dates in YYYY-MM-DD format.');
    }
    if (to && to < from) throw new BadRequestException('The effective end date must be on or after the start date.');
    if (input.dateOfBirth && this.day(this.date(input.dateOfBirth)) !== input.dateOfBirth) {
      throw new BadRequestException('Provide a valid date of birth.');
    }

    return this.prisma.$transaction(async (tx) => {
      const property = await tx.estateProperty.findFirst({
        where: { id: input.propertyId, estateId, status: { not: 'ARCHIVED' } }, select: { id: true },
      });
      if (!property) throw new NotFoundException('An active property was not found in this estate.');
      if (!(await this.hasPropertyRelationship(estateId, property.id, primaryUserId, from, to))) {
        throw new ForbiddenException('The household account holder must have an approved relationship with this property.');
      }
      const duplicate = await tx.householdMember.findFirst({
        where: {
          estateId, propertyId: property.id, primaryUserId,
          fullName: { equals: input.fullName.trim(), mode: 'insensitive' },
          status: { in: ACTIVE_STATUSES },
        },
        select: { id: true },
      });
      if (duplicate) throw new ConflictException('This person is already an active household member for the property.');

      const status = isManager ? 'ACTIVE' : 'PENDING_APPROVAL';
      const financialAccess = isManager && input.memberType === 'ADULT' && input.financialAccess === true;
      const member = await tx.householdMember.create({ data: {
        estateId, propertyId: property.id, primaryUserId,
        fullName: input.fullName.trim(), relationship: input.relationship, memberType: input.memberType,
        dateOfBirth: input.dateOfBirth ? this.date(input.dateOfBirth) : null,
        phone: input.phone?.trim() || null, email: input.email?.trim().toLowerCase() || null,
        linkedUserId: input.linkedUserId ?? null, financialAccess, status,
        effectiveFrom: from, effectiveTo: to, addedById: actorUserId,
        ...(isManager ? { decidedById: actorUserId, decidedAt: new Date(), decisionReason: 'Added by estate management.' } : {}),
      } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'household.member_added',
        targetType: 'household_member', targetId: member.id, outcome: 'success', occurredAt: new Date(),
        metadata: { propertyId: property.id, primaryUserId, status, memberType: input.memberType, financialAccess },
      } });
      const [decorated] = await this.decorate([member]);
      return decorated;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async decide(actorUserId: string, estateId: string, memberId: string, input: DecideHouseholdMemberDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.membership(actorUserId, estateId, true);
        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM household_members WHERE id = ${memberId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const member = await tx.householdMember.findFirst({ where: { id: memberId, estateId }, select: { id: true, status: true, memberType: true, financialAccess: true } });
        if (!member) throw new NotFoundException('Household member not found.');
        if (member.status !== 'PENDING_APPROVAL') throw new ConflictException('Only a pending household member can be approved or rejected.');
        const status = input.decision === 'approve' ? 'ACTIVE' : 'REJECTED';
        const updated = await tx.householdMember.update({ where: { id: memberId }, data: {
          status, decidedById: actorUserId, decidedAt: new Date(), decisionReason: input.note?.trim() || null,
          // Dependants and restricted members never receive financial privileges.
          financialAccess: status === 'ACTIVE' && member.memberType === 'ADULT' ? member.financialAccess : false,
        } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: input.decision === 'approve' ? 'household.member_approved' : 'household.member_rejected',
          targetType: 'household_member', targetId: memberId, outcome: 'success', occurredAt: new Date(),
          metadata: { decision: input.decision },
        } });
        const [decorated] = await this.decorate([updated]);
        return decorated;
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (['P2002', 'P2034'].includes((error as { code?: string })?.code ?? '')) {
        throw new ConflictException('This household member changed during review. Reload and try again.');
      }
      throw error;
    }
  }

  async end(actorUserId: string, estateId: string, memberId: string, input: EndHouseholdMemberDto) {
    return this.prisma.$transaction(async (tx) => {
      const membership = await this.membership(actorUserId, estateId);
      const isManager = MANAGEMENT_ROLES.includes(membership.role);
      const member = await tx.householdMember.findFirst({ where: { id: memberId, estateId }, select: { id: true, status: true, primaryUserId: true, effectiveFrom: true } });
      if (!member) throw new NotFoundException('Household member not found.');
      if (!isManager && member.primaryUserId !== actorUserId) {
        throw new ForbiddenException('Only estate management or the household account holder can end a membership.');
      }
      if (member.status === 'ENDED' || member.status === 'REJECTED') {
        throw new ConflictException('This household membership is already closed.');
      }
      if (input.effectiveTo && this.day(this.date(input.effectiveTo)) !== input.effectiveTo) {
        throw new BadRequestException('Provide a valid end date in YYYY-MM-DD format.');
      }
      const effectiveTo = input.effectiveTo
        ? this.date(input.effectiveTo)
        : new Date(`${this.businessToday()}T00:00:00.000Z`);
      if (effectiveTo < member.effectiveFrom) {
        throw new BadRequestException('The end date cannot be before the household membership started.');
      }
      const updated = await tx.householdMember.update({ where: { id: memberId }, data: {
        status: 'ENDED', effectiveTo, decisionReason: input.reason.trim(),
        ...(isManager ? { decidedById: actorUserId, decidedAt: new Date() } : {}),
      } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'household.member_ended',
        targetType: 'household_member', targetId: memberId, outcome: 'success', occurredAt: new Date(),
        metadata: { reason: input.reason.trim() },
      } });
      const [decorated] = await this.decorate([updated]);
      return decorated;
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }
}
