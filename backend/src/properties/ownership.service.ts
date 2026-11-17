import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OwnershipInterestStatus, OwnershipVerificationStatus, Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type {
  CreateOwnershipInterestDto,
  DecideOwnershipVerificationDto,
  EndOwnershipInterestDto,
  OwnershipQueryDto,
} from './ownership.dto.js';

const MANAGER_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER'] as const;

@Injectable()
export class OwnershipService {
  constructor(private readonly prisma: PrismaService) {}

  async list(actorUserId: string, estateId: string, query: OwnershipQueryDto) {
    await this.requireManager(actorUserId, estateId);
    const where = {
      estateId,
      ...(query.status ? { status: query.status.toUpperCase() as OwnershipInterestStatus } : {}),
      ...(query.verificationStatus ? { verificationStatus: query.verificationStatus.toUpperCase() as OwnershipVerificationStatus } : {}),
    };
    const [records, total] = await this.prisma.$transaction([
      this.prisma.estateOwnershipInterest.findMany({
        where,
        include: {
          owner: { select: { id: true, displayName: true, emailNormalized: true, phone: true } },
          property: { select: { id: true, code: true, propertyType: true, unitNumber: true } },
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.estateOwnershipInterest.count({ where }),
    ]);
    return {
      items: records.map((record) => this.reviewProjection(record)),
      page: query.page,
      pageSize: query.pageSize,
      total,
    };
  }

  async listPropertyOwners(actorUserId: string, estateId: string, propertyId: string) {
    const isManager = await this.hasManagerMembership(actorUserId, estateId);
    const property = await this.prisma.estateProperty.findFirst({
      where: { id: propertyId, estateId }, select: { id: true },
    });
    if (!property) throw new NotFoundException('Property not found.');
    if (!isManager) {
      const linked = await this.prisma.estateOwnershipInterest.findFirst({
        where: {
          estateId, propertyId, ownerUserId: actorUserId, status: 'ACTIVE',
          verificationStatus: 'VERIFIED', ...this.currentEffectiveDateFilter(),
        }, select: { id: true },
      });
      if (!linked) throw new NotFoundException('Property not found.');
    }
    const records = await this.prisma.estateOwnershipInterest.findMany({
      where: {
        estateId, propertyId,
        ...(isManager ? {} : { ownerUserId: actorUserId }),
      },
      include: { owner: { select: { id: true, displayName: true, emailNormalized: true } } },
      orderBy: [{ effectiveFrom: 'desc' }, { createdAt: 'desc' }],
    });
    return { items: records.map((record) => ({
      id: record.id,
      owner: record.owner,
      share: record.ownershipShare.toFixed(2),
      effectiveFrom: dateString(record.effectiveFrom),
      effectiveTo: record.effectiveTo ? dateString(record.effectiveTo) : null,
      status: record.status.toLowerCase(),
      verificationStatus: record.verificationStatus.toLowerCase(),
      evidenceNote: isManager || record.ownerUserId === actorUserId ? record.evidenceNote : null,
      reviewReason: record.reviewReason,
    })) };
  }

  async create(actorUserId: string, estateId: string, propertyId: string, dto: CreateOwnershipInterestDto) {
    const ownerEmail = dto.ownerEmail.trim().toLowerCase();
    const share = parseShare(dto.ownershipShare);
    const from = this.requireCalendarDate(dto.effectiveFrom, 'Ownership start date');
    const to = dto.effectiveTo ? this.requireCalendarDate(dto.effectiveTo, 'Ownership end date') : null;
    if (to && to < from) throw new BadRequestException('Ownership end date cannot precede its start date.');
    const evidenceNote = dto.evidenceNote.trim();
    if (!evidenceNote) throw new BadRequestException('Record the ownership evidence checked by the estate team.');

    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireManager(actorUserId, estateId, tx);
        const propertyRows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          SELECT id FROM estate_properties
          WHERE id = ${propertyId}::uuid AND estate_id = ${estateId}::uuid AND status <> 'ARCHIVED'
          FOR UPDATE
        `);
        if (!propertyRows.length) throw new NotFoundException('Property not found.');
        const owner = await tx.user.findFirst({
          where: { emailNormalized: ownerEmail, status: 'ACTIVE' },
          select: { id: true },
        });
        if (!owner) throw new NotFoundException('An active account with this email was not found.');

        const existing = await tx.estateOwnershipInterest.findMany({
          where: {
            estateId, propertyId, status: 'ACTIVE', verificationStatus: { not: 'REJECTED' },
          },
          select: { ownerUserId: true, ownershipShare: true, effectiveFrom: true, effectiveTo: true },
        });
        const overlaps = existing.filter((record) => dateRangesOverlap(
          from, to, dateString(record.effectiveFrom), record.effectiveTo ? dateString(record.effectiveTo) : null,
        ));
        if (overlaps.some((record) => record.ownerUserId === owner.id)) {
          throw new ConflictException('This owner already has an ownership period that overlaps these dates.');
        }
        const committedShare = overlaps.reduce((sum, record) => sum.plus(record.ownershipShare), new Prisma.Decimal(0));
        if (committedShare.plus(share).greaterThan(100)) {
          throw new ConflictException('This ownership share would exceed 100% for the selected period.');
        }

        const now = new Date();
        const record = await tx.estateOwnershipInterest.create({
          data: {
            estateId, propertyId, ownerUserId: owner.id,
            ownershipShare: share, effectiveFrom: from,
            effectiveTo: to, evidenceNote, createdById: actorUserId,
          },
          include: {
            owner: { select: { id: true, displayName: true, emailNormalized: true, phone: true } },
            property: { select: { id: true, code: true, propertyType: true, unitNumber: true } },
          },
        });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'ownership.created',
          targetType: 'ownership_interest', targetId: record.id, outcome: 'success', occurredAt: now,
          metadata: { verificationStatus: 'pending', propertyId, ownerUserId: owner.id, ownershipShare: share.toFixed(2) },
        } });
        return this.reviewProjection(record);
      }, { isolationLevel: 'Serializable' });
    } catch (error) {
      this.rethrowWriteConflict(error, 'Ownership changed while the record was being saved. Reload and try again.');
      throw error;
    }
  }

  async decide(actorUserId: string, estateId: string, ownershipId: string, dto: DecideOwnershipVerificationDto) {
    const reason = dto.reason.trim();
    if (!reason) throw new BadRequestException('Record why the ownership evidence was accepted or rejected.');
    return this.prisma.$transaction(async (tx) => {
      await this.requireManager(actorUserId, estateId, tx);
      const current = await tx.estateOwnershipInterest.findFirst({
        where: { id: ownershipId, estateId }, select: { id: true, propertyId: true, ownerUserId: true, status: true, verificationStatus: true },
      });
      if (!current) throw new NotFoundException('Ownership interest not found.');
      if (current.status !== 'ACTIVE' || current.verificationStatus !== 'PENDING') {
        throw new ConflictException('Only a pending ownership record can be reviewed.');
      }
      await this.lockProperty(tx, estateId, current.propertyId);
      const now = new Date();
      const verificationStatus = dto.decision === 'verify' ? 'VERIFIED' : 'REJECTED';
      const changed = await tx.estateOwnershipInterest.updateMany({
        where: { id: ownershipId, estateId, status: 'ACTIVE', verificationStatus: 'PENDING' },
        data: { verificationStatus, reviewReason: reason, reviewedById: actorUserId, reviewedAt: now },
      });
      if (changed.count !== 1) throw new ConflictException('Another manager already reviewed this ownership record.');
      if (verificationStatus === 'VERIFIED') {
        const landlordMembership = await tx.estateMembership.findUnique({
          where: { estateId_userId_role: { estateId, userId: current.ownerUserId, role: 'LANDLORD' } },
          select: { id: true },
        });
        if (!landlordMembership) {
          const membership = await tx.estateMembership.create({
            data: { estateId, userId: current.ownerUserId, role: 'LANDLORD', status: 'ACTIVE' },
            select: { id: true },
          });
          await tx.auditEvent.create({ data: {
            actorUserId, scope: 'estate', estateId, action: 'membership.landlord_access_granted',
            targetType: 'estate_membership', targetId: membership.id, outcome: 'success',
            reason: 'Granted after verified property ownership.', occurredAt: now,
          } });
        }
      }
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: `ownership.${dto.decision}`,
        targetType: 'ownership_interest', targetId: ownershipId, outcome: 'success', reason, occurredAt: now,
      } });
      return { id: ownershipId, estateId, verificationStatus: verificationStatus.toLowerCase(), reviewedAt: now };
    }, { isolationLevel: 'Serializable' }).catch((error: unknown) => {
      this.rethrowWriteConflict(error, 'Another review changed this ownership record. Reload and try again.');
      throw error;
    });
  }

  async end(actorUserId: string, estateId: string, ownershipId: string, dto: EndOwnershipInterestDto) {
    const effectiveTo = this.requireCalendarDate(dto.effectiveTo, 'Ownership end date');
    const reason = dto.reason.trim();
    if (!reason) throw new BadRequestException('A reason is required to end ownership.');
    if (effectiveTo > utcToday()) throw new BadRequestException('Ownership can only be ended on or before today.');
    return this.prisma.$transaction(async (tx) => {
      await this.requireManager(actorUserId, estateId, tx);
      const current = await tx.estateOwnershipInterest.findFirst({
        where: { id: ownershipId, estateId }, select: { id: true, propertyId: true, status: true, effectiveFrom: true },
      });
      if (!current) throw new NotFoundException('Ownership interest not found.');
      if (current.status !== 'ACTIVE') throw new ConflictException('Only active ownership can be ended.');
      if (effectiveTo < dateString(current.effectiveFrom)) throw new BadRequestException('Ownership end date cannot precede its start date.');
      await this.lockProperty(tx, estateId, current.propertyId);
      const now = new Date();
      const changed = await tx.estateOwnershipInterest.updateMany({
        where: { id: ownershipId, estateId, status: 'ACTIVE' },
        data: { status: 'ENDED', effectiveTo, endReason: reason },
      });
      if (changed.count !== 1) throw new ConflictException('Ownership changed while it was being ended.');
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'ownership.end',
        targetType: 'ownership_interest', targetId: ownershipId, outcome: 'success', reason, occurredAt: now,
        metadata: { effectiveTo },
      } });
      return { id: ownershipId, estateId, status: 'ended', effectiveTo };
    }, { isolationLevel: 'Serializable' }).catch((error: unknown) => {
      this.rethrowWriteConflict(error, 'Another change affected this ownership record. Reload and try again.');
      throw error;
    });
  }

  async landlordPortfolio(actorUserId: string, estateId: string) {
    const today = utcToday();
    const rows = await this.prisma.estateOwnershipInterest.findMany({
      where: {
        estateId, ownerUserId: actorUserId, status: 'ACTIVE', verificationStatus: 'VERIFIED',
        effectiveFrom: { lte: new Date(`${today}T00:00:00.000Z`) },
        OR: [{ effectiveTo: null }, { effectiveTo: { gte: new Date(`${today}T00:00:00.000Z`) } }],
        estate: {
          status: 'ACTIVE',
          memberships: { some: { userId: actorUserId, role: 'LANDLORD', status: 'ACTIVE' } },
        },
        property: { status: { not: 'ARCHIVED' } },
      },
      include: {
        estate: { select: { id: true, name: true, estateCode: true, address: true, state: true, lga: true } },
        property: {
          select: {
            id: true, estateId: true, code: true, propertyType: true, unitNumber: true, address: true, status: true,
            structureLinks: { select: { node: { select: { id: true, type: true, name: true, code: true } } } },
            occupancies: {
              where: {
                status: 'ACTIVE', effectiveFrom: { lte: new Date(`${today}T00:00:00.000Z`) },
                OR: [{ effectiveTo: null }, { effectiveTo: { gte: new Date(`${today}T00:00:00.000Z`) } }],
              },
              select: { id: true },
            },
            tenancies: {
              where: {
                status: 'ACTIVE', effectiveFrom: { lte: new Date(`${today}T00:00:00.000Z`) },
                OR: [{ effectiveTo: null }, { effectiveTo: { gte: new Date(`${today}T00:00:00.000Z`) } }],
              },
              select: {
                id: true, rentAmount: true, currency: true, rentFrequency: true, rentDueDay: true,
                effectiveFrom: true, effectiveTo: true,
                tenant: { select: { displayName: true } },
              },
              take: 1,
            },
            ownershipInterests: {
              where: {
                ownerUserId: actorUserId, status: 'ACTIVE', verificationStatus: 'VERIFIED',
                effectiveFrom: { lte: new Date(`${today}T00:00:00.000Z`) },
                OR: [{ effectiveTo: null }, { effectiveTo: { gte: new Date(`${today}T00:00:00.000Z`) } }],
              },
              select: { ownershipShare: true, effectiveFrom: true, effectiveTo: true },
              orderBy: { effectiveFrom: 'desc' },
              take: 1,
            },
          },
        },
      },
      orderBy: [{ effectiveFrom: 'desc' }, { createdAt: 'desc' }],
      take: 200,
    });
    const byProperty = new Map<string, (typeof rows)[number]>();
    for (const row of rows) if (!byProperty.has(row.propertyId)) byProperty.set(row.propertyId, row);
    return { items: [...byProperty.values()].map((row) => ({
      id: row.property.id, estateId, estate: row.estate,
      property: {
        id: row.property.id, code: row.property.code, propertyType: row.property.propertyType,
        status: row.property.status.toLowerCase(), unitNumber: row.property.unitNumber, address: row.property.address,
        structure: row.property.structureLinks.map(({ node }) => ({ id: node.id, type: node.type.toLowerCase(), name: node.name, code: node.code })),
      },
      ownership: {
        share: row.property.ownershipInterests[0]?.ownershipShare.toFixed(2) ?? row.ownershipShare.toFixed(2),
        effectiveFrom: row.property.ownershipInterests[0] ? dateString(row.property.ownershipInterests[0].effectiveFrom) : dateString(row.effectiveFrom),
        effectiveTo: row.property.ownershipInterests[0]?.effectiveTo ? dateString(row.property.ownershipInterests[0].effectiveTo!) : null,
      },
      occupancy: { occupied: row.property.occupancies.length > 0, currentOccupantCount: row.property.occupancies.length },
      currentTenancy: row.property.tenancies[0] ? {
        id: row.property.tenancies[0].id,
        tenantDisplayName: row.property.tenancies[0].tenant.displayName,
        rent: {
          amount: row.property.tenancies[0].rentAmount.toFixed(2),
          currency: row.property.tenancies[0].currency,
          frequency: row.property.tenancies[0].rentFrequency.toLowerCase(),
          dueDay: row.property.tenancies[0].rentDueDay,
        },
        effectiveFrom: dateString(row.property.tenancies[0].effectiveFrom),
        effectiveTo: row.property.tenancies[0].effectiveTo ? dateString(row.property.tenancies[0].effectiveTo) : null,
      } : null,
    })) };
  }

  async myLandlordEstates(actorUserId: string) {
    const ownerships = await this.prisma.estateOwnershipInterest.findMany({
      where: {
        ownerUserId: actorUserId, status: 'ACTIVE', verificationStatus: 'VERIFIED',
        ...this.currentEffectiveDateFilter(),
        estate: {
          status: 'ACTIVE',
          memberships: { some: { userId: actorUserId, role: 'LANDLORD', status: 'ACTIVE' } },
        },
        property: { status: { not: 'ARCHIVED' } },
      },
      select: { estate: { select: { id: true, estateCode: true, name: true, estateType: true, address: true, state: true, lga: true } } },
      distinct: ['estateId'], orderBy: { estate: { name: 'asc' } }, take: 200,
    });
    return { items: ownerships.map(({ estate }) => ({ ...estate, roles: ['landlord'] })) };
  }

  private reviewProjection(record: {
    id: string; estateId: string; propertyId: string; ownerUserId: string; ownershipShare: Prisma.Decimal;
    effectiveFrom: Date; effectiveTo: Date | null; status: OwnershipInterestStatus;
    verificationStatus: OwnershipVerificationStatus; evidenceNote: string; reviewReason: string | null;
    reviewedAt: Date | null; createdAt: Date;
    owner: { id: string; displayName: string; emailNormalized: string; phone?: string | null };
    property: { id: string; code: string; propertyType: string; unitNumber: string | null };
  }) {
    return {
      id: record.id, estateId: record.estateId, propertyId: record.propertyId,
      owner: record.owner, property: record.property,
      share: record.ownershipShare.toFixed(2),
      effectiveFrom: dateString(record.effectiveFrom), effectiveTo: record.effectiveTo ? dateString(record.effectiveTo) : null,
      status: record.status.toLowerCase(), verificationStatus: record.verificationStatus.toLowerCase(),
      evidenceNote: record.evidenceNote, reviewReason: record.reviewReason,
      reviewedAt: record.reviewedAt, createdAt: record.createdAt,
    };
  }

  private currentEffectiveDateFilter() {
    const today = new Date(`${utcToday()}T00:00:00.000Z`);
    return { effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }] };
  }

  private requireCalendarDate(value: string, label: string): string {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new BadRequestException(`${label} must use YYYY-MM-DD.`);
    const date = new Date(`${value}T00:00:00.000Z`);
    if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== value) throw new BadRequestException(`${label} must be a valid calendar date.`);
    return value;
  }

  private async lockProperty(tx: Prisma.TransactionClient, estateId: string, propertyId: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
      SELECT id FROM estate_properties WHERE id = ${propertyId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE
    `);
    if (!rows.length) throw new NotFoundException('Property not found.');
  }

  private async requireManager(actorUserId: string, estateId: string, tx: Prisma.TransactionClient | PrismaService = this.prisma) {
    if (!(await this.hasManagerMembership(actorUserId, estateId, tx))) {
      throw new ForbiddenException('Active estate ownership management access is required.');
    }
  }

  private async hasManagerMembership(actorUserId: string, estateId: string, tx: Prisma.TransactionClient | PrismaService = this.prisma) {
    const membership = await tx.estateMembership.findFirst({
      where: { userId: actorUserId, estateId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES] }, estate: { status: 'ACTIVE' } },
      select: { id: true },
    });
    return membership !== null;
  }

  private rethrowWriteConflict(error: unknown, message: string) {
    if (typeof error === 'object' && error !== null && 'code' in error && (error as { code?: unknown }).code === 'P2034') {
      throw new ConflictException(message);
    }
  }
}

function parseShare(value: string) {
  if (!/^(?:0|[1-9]\d{0,2})(?:\.\d{1,2})?$/.test(value)) throw new BadRequestException('Ownership share must be a decimal from 0.01 to 100.00.');
  const share = new Prisma.Decimal(value);
  if (share.lessThanOrEqualTo(0) || share.greaterThan(100)) throw new BadRequestException('Ownership share must be a decimal from 0.01 to 100.00.');
  return share;
}

function dateString(date: Date) { return date.toISOString().slice(0, 10); }
function utcToday() { return new Date().toISOString().slice(0, 10); }
function dateRangesOverlap(aFrom: string, aTo: string | null, bFrom: string, bTo: string | null) {
  return (aTo === null || bFrom <= aTo) && (bTo === null || aFrom <= bTo);
}
