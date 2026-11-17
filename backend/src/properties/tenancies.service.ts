import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, RentFrequency, TenancyStatus } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { ApproveTenancyDto, CreateTenancyDto, TenancyQueryDto, TerminateTenancyDto } from './tenancies.dto.js';

const MANAGER_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER'] as const;
const FINANCE_MANAGER_ROLES = [...MANAGER_ROLES, 'FINANCE_MANAGER'] as const;

@Injectable()
export class TenanciesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(actorUserId: string, estateId: string, query: TenancyQueryDto) {
    await this.requireManager(actorUserId, estateId);
    const where = {
      estateId,
      ...(query.status ? { status: query.status.toUpperCase() as TenancyStatus } : {}),
    };
    const [records, total] = await this.prisma.$transaction([
      this.prisma.estateTenancy.findMany({
        where,
        include: {
          property: { select: { id: true, code: true, propertyType: true, unitNumber: true } },
          tenant: { select: { id: true, displayName: true, emailNormalized: true, phone: true } },
          payee: { select: { id: true, displayName: true, emailNormalized: true } },
        },
        orderBy: [{ effectiveFrom: 'desc' }, { createdAt: 'desc' }],
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.estateTenancy.count({ where }),
    ]);
    return { items: records.map((record) => this.project(record)), page: query.page, pageSize: query.pageSize, total };
  }

  async previewRentSchedule(actorUserId: string, estateId: string, year: number, month: number) {
    await this.requireFinanceAccess(actorUserId, estateId);
    const periodStart = new Date(Date.UTC(year, month - 1, 1));
    const periodEnd = new Date(Date.UTC(year, month, 0));
    const rows = await this.prisma.estateTenancy.findMany({
      where: {
        estateId, status: 'ACTIVE', effectiveFrom: { lte: periodEnd },
        OR: [{ effectiveTo: null }, { effectiveTo: { gte: periodStart } }],
      },
      include: {
        property: { select: { code: true, unitNumber: true } },
        tenant: { select: { displayName: true } },
        payee: { select: { displayName: true } },
      },
      orderBy: [{ rentDueDay: 'asc' }, { property: { code: 'asc' } }], take: 500,
    });
    const items = rows.flatMap((tenancy) => {
      const monthsSinceStart = (year - tenancy.effectiveFrom.getUTCFullYear()) * 12 + month - tenancy.effectiveFrom.getUTCMonth() - 1;
      const interval = tenancy.rentFrequency === 'MONTHLY' ? 1 : tenancy.rentFrequency === 'QUARTERLY' ? 3 : 12;
      if (monthsSinceStart < 0 || monthsSinceStart % interval !== 0) return [];
      const day = Math.min(tenancy.rentDueDay, periodEnd.getUTCDate());
      const dueDate = new Date(Date.UTC(year, month - 1, day));
      if (dueDate < tenancy.effectiveFrom || (tenancy.effectiveTo && dueDate > tenancy.effectiveTo)) return [];
      return [{
        tenancyId: tenancy.id, propertyCode: tenancy.property.code, unitNumber: tenancy.property.unitNumber,
        tenantName: tenancy.tenant.displayName, rentPayeeName: tenancy.payee.displayName,
        amount: tenancy.rentAmount.toFixed(2), currency: tenancy.currency,
        frequency: tenancy.rentFrequency.toLowerCase(), dueDate: dateString(dueDate),
      }];
    });
    return { estateId, period: `${year}-${String(month).padStart(2, '0')}`, source: 'active_approved_tenancies', invoiceCreated: false, items, total: items.length };
  }

  async create(actorUserId: string, estateId: string, propertyId: string, dto: CreateTenancyDto) {
    const tenantEmail = dto.tenantEmail.trim().toLowerCase();
    const payeeEmail = dto.payeeEmail.trim().toLowerCase();
    const rentAmount = this.money(dto.rentAmount, 'Rent amount', false)!;
    const depositAmount = dto.depositAmount == null || dto.depositAmount.trim() === ''
      ? null : this.money(dto.depositAmount, 'Deposit amount', true);
    const from = this.calendarDate(dto.effectiveFrom, 'Tenancy start date');
    const to = dto.effectiveTo ? this.calendarDate(dto.effectiveTo, 'Tenancy end date') : null;
    if (to && to < from) throw new BadRequestException('Tenancy end date cannot precede its start date.');
    const termsNote = dto.termsNote?.trim() || null;

    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireManager(actorUserId, estateId, tx);
        await this.lockProperty(tx, estateId, propertyId);
        const property = await tx.estateProperty.findFirst({
          where: { id: propertyId, estateId, status: 'ACTIVE' }, select: { id: true },
        });
        if (!property) throw new NotFoundException('Active property not found.');
        const tenant = await tx.user.findFirst({ where: { emailNormalized: tenantEmail, status: 'ACTIVE' }, select: { id: true } });
        const payee = await tx.user.findFirst({ where: { emailNormalized: payeeEmail, status: 'ACTIVE' }, select: { id: true } });
        if (!tenant) throw new NotFoundException('An active tenant account with this email was not found.');
        if (!payee) throw new NotFoundException('An active landlord account with this email was not found.');
        if (tenant.id === payee.id) throw new BadRequestException('The tenant and rent payee must be different accounts.');

        const ownership = await tx.estateOwnershipInterest.findFirst({
          where: {
            estateId, propertyId, ownerUserId: payee.id, status: 'ACTIVE', verificationStatus: 'VERIFIED',
            effectiveFrom: { lte: dateAtUtc(from) },
            OR: [{ effectiveTo: null }, ...(to ? [{ effectiveTo: { gte: dateAtUtc(to) } }] : [{ effectiveTo: { gte: dateAtUtc(from) } }])],
          }, select: { id: true, effectiveTo: true },
        });
        if (!ownership) throw new BadRequestException('The selected rent payee must have verified ownership effective on the tenancy start date.');

        const overlaps = await tx.estateTenancy.findMany({
          where: { estateId, propertyId, status: { in: ['PENDING_APPROVAL', 'ACTIVE', 'TERMINATED'] } },
          select: { tenantUserId: true, effectiveFrom: true, effectiveTo: true, status: true, terminationEffectiveDate: true },
        });
        if (overlaps.some((record) => dateRangesOverlap(from, to, dateString(record.effectiveFrom), tenancyEndDate(record)))) {
          throw new ConflictException('Another pending or active tenancy overlaps these dates for this property.');
        }
        const tenantOccupancies = await tx.propertyOccupancy.findMany({
          where: { estateId, propertyId, relationship: 'TENANT', status: 'ACTIVE' },
          select: { effectiveFrom: true, effectiveTo: true },
        });
        if (tenantOccupancies.some((record) => dateRangesOverlap(
          from, to, dateString(record.effectiveFrom), record.effectiveTo ? dateString(record.effectiveTo) : null,
        ))) throw new ConflictException('A tenant occupancy already overlaps these tenancy dates.');

        const now = new Date();
        const record = await tx.estateTenancy.create({
          data: {
            estateId, propertyId, tenantUserId: tenant.id, payeeUserId: payee.id,
            rentAmount, currency: dto.currency, rentFrequency: dto.rentFrequency.toUpperCase() as RentFrequency,
            rentDueDay: dto.rentDueDay, depositAmount, effectiveFrom: from, effectiveTo: to,
            termsNote, createdById: actorUserId,
          },
          include: {
            property: { select: { id: true, code: true, propertyType: true, unitNumber: true } },
            tenant: { select: { id: true, displayName: true, emailNormalized: true, phone: true } },
            payee: { select: { id: true, displayName: true, emailNormalized: true } },
          },
        });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'tenancy.created', targetType: 'tenancy', targetId: record.id,
          outcome: 'success', occurredAt: now,
          metadata: { propertyId, tenantUserId: tenant.id, payeeUserId: payee.id, rentAmount: rentAmount.toFixed(2), currency: dto.currency },
        } });
        return this.project(record);
      }, { isolationLevel: 'Serializable' });
    } catch (error) {
      this.rethrowWriteConflict(error, 'Tenancy changed while it was being saved. Reload and try again.');
      throw error;
    }
  }

  async approve(actorUserId: string, estateId: string, tenancyId: string, dto: ApproveTenancyDto) {
    const reason = dto.reason.trim();
    if (!reason) throw new BadRequestException('A reason is required to approve this tenancy.');
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireManager(actorUserId, estateId, tx);
        const current = await tx.estateTenancy.findFirst({
          where: { id: tenancyId, estateId },
          select: { id: true, propertyId: true, tenantUserId: true, payeeUserId: true, status: true, effectiveFrom: true, effectiveTo: true },
        });
        if (!current) throw new NotFoundException('Tenancy not found.');
        if (current.status !== 'PENDING_APPROVAL') throw new ConflictException('Only a pending tenancy can be approved.');
        const today = utcToday();
        if (dateString(current.effectiveFrom) > today || (current.effectiveTo && dateString(current.effectiveTo) < today)) {
          throw new BadRequestException('Approve the tenancy on or after its start date and before its end date.');
        }
        await this.lockProperty(tx, estateId, current.propertyId);
        const property = await tx.estateProperty.findFirst({ where: { id: current.propertyId, estateId, status: 'ACTIVE' }, select: { id: true } });
        if (!property) throw new ConflictException('The property is no longer active.');
        const todayDate = dateAtUtc(today);
        const ownershipCoverage = await tx.estateOwnershipInterest.findMany({
          where: {
            estateId, propertyId: current.propertyId, ownerUserId: current.payeeUserId, status: 'ACTIVE',
            verificationStatus: 'VERIFIED', effectiveFrom: { lte: todayDate },
            OR: [{ effectiveTo: null }, { effectiveTo: { gte: todayDate } }],
          }, select: { effectiveFrom: true, effectiveTo: true },
          orderBy: { effectiveFrom: 'asc' },
        });
        const requiredEnd = current.effectiveTo ? dateString(current.effectiveTo) : null;
        let coveredThrough = today;
        for (const interest of ownershipCoverage) {
          if (dateString(interest.effectiveFrom) > nextCalendarDay(coveredThrough)) break;
          if (interest.effectiveTo === null) { coveredThrough = '9999-12-31'; break; }
          if (dateString(interest.effectiveTo) > coveredThrough) coveredThrough = dateString(interest.effectiveTo);
        }
        const ownershipEndsTooSoon = requiredEnd === null ? coveredThrough !== '9999-12-31' : coveredThrough < requiredEnd;
        if (!ownershipCoverage.length || ownershipEndsTooSoon) {
          throw new ConflictException('The rent payee must retain verified ownership for the tenancy term before activation.');
        }
        const overlaps = await tx.estateTenancy.findMany({
          where: { estateId, propertyId: current.propertyId, id: { not: tenancyId }, status: { in: ['PENDING_APPROVAL', 'ACTIVE', 'TERMINATED'] } },
          select: { effectiveFrom: true, effectiveTo: true, status: true, terminationEffectiveDate: true },
        });
        if (overlaps.some((record) => dateRangesOverlap(
          dateString(current.effectiveFrom), current.effectiveTo ? dateString(current.effectiveTo) : null,
          dateString(record.effectiveFrom), tenancyEndDate(record),
        ))) throw new ConflictException('A different pending or active tenancy overlaps this period.');

        const existingOccupancy = await tx.propertyOccupancy.findFirst({
          where: { estateId, propertyId: current.propertyId, relationship: 'TENANT', status: 'ACTIVE', effectiveFrom: { lte: current.effectiveTo ?? dateAtUtc('9999-12-31') }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: current.effectiveFrom } }] }, select: { id: true },
        });
        if (existingOccupancy) throw new ConflictException('A tenant occupancy already overlaps this tenancy period.');

        const now = new Date();
        const changed = await tx.estateTenancy.updateMany({
          where: { id: tenancyId, estateId, status: 'PENDING_APPROVAL' },
          data: { status: 'ACTIVE', approvedById: actorUserId, approvedAt: now },
        });
        if (changed.count !== 1) throw new ConflictException('Another manager already changed this tenancy.');
        await tx.propertyOccupancy.create({
          data: {
            estateId, propertyId: current.propertyId, residentId: current.tenantUserId,
            relationship: 'TENANT', status: 'ACTIVE', effectiveFrom: current.effectiveFrom,
            effectiveTo: current.effectiveTo, tenancyId, createdById: actorUserId,
          },
        });
        await tx.estateMembership.upsert({
          where: { estateId_userId_role: { estateId, userId: current.tenantUserId, role: 'RESIDENT' } },
          create: { estateId, userId: current.tenantUserId, role: 'RESIDENT', status: 'ACTIVE' },
          update: { status: 'ACTIVE' },
        });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'tenancy.approved', targetType: 'tenancy', targetId: tenancyId,
          outcome: 'success', reason, occurredAt: now,
          metadata: { propertyId: current.propertyId, tenantUserId: current.tenantUserId },
        } });
        return { id: tenancyId, estateId, status: 'active', approvedAt: now };
      }, { isolationLevel: 'Serializable' });
    } catch (error) {
      this.rethrowWriteConflict(error, 'Another tenancy change conflicts with this approval. Reload and try again.');
      throw error;
    }
  }

  async terminate(actorUserId: string, estateId: string, tenancyId: string, dto: TerminateTenancyDto) {
    const effectiveTo = this.calendarDate(dto.effectiveTo, 'Termination date');
    const reason = dto.reason.trim();
    if (!reason) throw new BadRequestException('A reason is required to terminate this tenancy.');
    if (effectiveTo > utcToday()) throw new BadRequestException('A tenancy can only be terminated on or before today.');
    return this.prisma.$transaction(async (tx) => {
      await this.requireManager(actorUserId, estateId, tx);
      const current = await tx.estateTenancy.findFirst({
        where: { id: tenancyId, estateId },
        select: { id: true, propertyId: true, tenantUserId: true, status: true, effectiveFrom: true, effectiveTo: true },
      });
      if (!current) throw new NotFoundException('Tenancy not found.');
      if (current.status !== 'ACTIVE') throw new ConflictException('Only an active tenancy can be terminated.');
      if (effectiveTo < dateString(current.effectiveFrom)) throw new BadRequestException('Termination date cannot precede the tenancy start date.');
      if (current.effectiveTo && effectiveTo > dateString(current.effectiveTo)) throw new BadRequestException('Termination date cannot follow the tenancy end date.');
      await this.lockProperty(tx, estateId, current.propertyId);
      const now = new Date();
      const changed = await tx.estateTenancy.updateMany({
        where: { id: tenancyId, estateId, status: 'ACTIVE' },
        data: { status: 'TERMINATED', terminatedById: actorUserId, terminatedAt: now, terminationEffectiveDate: effectiveTo, terminationReason: reason },
      });
      if (changed.count !== 1) throw new ConflictException('Another manager already changed this tenancy.');
      await tx.propertyOccupancy.updateMany({
        where: { tenancyId, status: 'ACTIVE' }, data: { status: 'ENDED', effectiveTo, endedById: actorUserId },
      });
      const remaining = await tx.propertyOccupancy.count({
      where: { estateId, residentId: current.tenantUserId, status: 'ACTIVE', effectiveFrom: { lte: dateAtUtc(utcToday()) }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: dateAtUtc(utcToday()) } }] },
      });
      if (remaining === 0) await tx.estateMembership.updateMany({
        where: { estateId, userId: current.tenantUserId, role: 'RESIDENT', status: 'ACTIVE' }, data: { status: 'REVOKED' },
      });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'tenancy.terminated', targetType: 'tenancy', targetId: tenancyId,
        outcome: 'success', reason, occurredAt: now, metadata: { effectiveTo },
      } });
      return { id: tenancyId, estateId, status: 'terminated', effectiveTo };
    }, { isolationLevel: 'Serializable' }).catch((error: unknown) => {
      this.rethrowWriteConflict(error, 'Another change affected this tenancy. Reload and try again.');
      throw error;
    });
  }

  private project(record: {
    id: string; estateId: string; propertyId: string; status: TenancyStatus; rentAmount: Prisma.Decimal; currency: string;
    rentFrequency: RentFrequency; rentDueDay: number; depositAmount: Prisma.Decimal | null; effectiveFrom: Date; effectiveTo: Date | null;
    termsNote: string | null; approvedAt: Date | null; terminatedAt: Date | null; terminationEffectiveDate: Date | null;
    terminationReason: string | null; createdAt: Date;
    property: { id: string; code: string; propertyType: string; unitNumber: string | null };
    tenant: { id: string; displayName: string; emailNormalized: string; phone?: string | null };
    payee: { id: string; displayName: string; emailNormalized: string };
  }) {
    return {
      id: record.id, estateId: record.estateId, status: record.status.toLowerCase(),
      property: record.property, tenant: record.tenant, payee: record.payee,
      rent: { amount: record.rentAmount.toFixed(2), currency: record.currency, frequency: record.rentFrequency.toLowerCase(), dueDay: record.rentDueDay },
      depositAmount: record.depositAmount?.toFixed(2) ?? null,
      effectiveFrom: dateString(record.effectiveFrom), effectiveTo: record.effectiveTo ? dateString(record.effectiveTo) : null,
      termsNote: record.termsNote, approvedAt: record.approvedAt, terminatedAt: record.terminatedAt,
      terminationEffectiveDate: record.terminationEffectiveDate ? dateString(record.terminationEffectiveDate) : null,
      terminationReason: record.terminationReason, createdAt: record.createdAt,
    };
  }

  private money(value: string, label: string, allowZero: boolean) {
    if (!/^(?:0|[1-9]\d{0,9})(?:\.\d{1,2})?$/.test(value)) throw new BadRequestException(`${label} must be a non-negative amount with up to two decimal places.`);
    const amount = new Prisma.Decimal(value);
    if (allowZero ? amount.lessThan(0) : amount.lessThanOrEqualTo(0)) throw new BadRequestException(`${label} must be ${allowZero ? 'non-negative' : 'greater than zero'}.`);
    return amount;
  }

  private calendarDate(value: string, label: string): string {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new BadRequestException(`${label} must use YYYY-MM-DD.`);
    const parsed = new Date(`${value}T00:00:00.000Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) throw new BadRequestException(`${label} must be a valid calendar date.`);
    return value;
  }

  private async lockProperty(tx: Prisma.TransactionClient, estateId: string, propertyId: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`SELECT id FROM estate_properties WHERE id = ${propertyId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`);
    if (!rows.length) throw new NotFoundException('Property not found.');
  }

  private async requireManager(actorUserId: string, estateId: string, tx: Prisma.TransactionClient | PrismaService = this.prisma) {
    const membership = await tx.estateMembership.findFirst({
      where: { userId: actorUserId, estateId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES] }, estate: { status: 'ACTIVE' } }, select: { id: true },
    });
    if (!membership) throw new ForbiddenException('Active estate tenancy management access is required.');
  }

  private async requireFinanceAccess(actorUserId: string, estateId: string) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: { userId: actorUserId, estateId, status: 'ACTIVE', role: { in: [...FINANCE_MANAGER_ROLES] }, estate: { status: 'ACTIVE' } }, select: { id: true },
    });
    if (!membership) throw new ForbiddenException('Active estate finance access is required.');
  }

  private rethrowWriteConflict(error: unknown, message: string) {
    if (typeof error === 'object' && error !== null && 'code' in error && (error as { code?: unknown }).code === 'P2034') throw new ConflictException(message);
  }
}

function dateAtUtc(value: string) { return new Date(`${value}T00:00:00.000Z`); }
function dateString(value: Date) { return value.toISOString().slice(0, 10); }
function utcToday() { return new Date().toISOString().slice(0, 10); }
function nextCalendarDay(value: string) {
  const next = new Date(`${value}T00:00:00.000Z`);
  next.setUTCDate(next.getUTCDate() + 1);
  return next.toISOString().slice(0, 10);
}
function tenancyEndDate(record: { status: TenancyStatus; effectiveTo: Date | null; terminationEffectiveDate: Date | null }) {
  const contractualEnd = record.effectiveTo ? dateString(record.effectiveTo) : null;
  const terminationEnd = record.status === 'TERMINATED' && record.terminationEffectiveDate
    ? dateString(record.terminationEffectiveDate)
    : null;
  if (contractualEnd === null) return terminationEnd;
  if (terminationEnd === null) return contractualEnd;
  return contractualEnd < terminationEnd ? contractualEnd : terminationEnd;
}
function dateRangesOverlap(aFrom: string, aTo: string | null, bFrom: string, bTo: string | null) {
  return (aTo === null || bFrom <= aTo) && (bTo === null || aFrom <= bTo);
}
