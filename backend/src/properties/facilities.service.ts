import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateEstateFacilityDto, CreateFacilityBookingDto, ReviewFacilityBookingDto } from './facilities.dto.js';

const MANAGERS = ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER'] as const;
const digest = (value: string) => createHash('sha256').update(value, 'utf8').digest('hex');

@Injectable()
export class EstateFacilitiesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(actorId: string, estateId: string) {
    await this.requireFacilityRead(actorId, estateId);
    const items = await this.prisma.estateFacility.findMany({ where: { estateId, active: true }, orderBy: [{ category: 'asc' }, { name: 'asc' }], take: 100 });
    return { estateId, items: items.map((item) => this.facilityView(item)) };
  }

  async create(actorId: string, estateId: string, input: CreateEstateFacilityDto) {
    this.validateHours(input.openingTime, input.closingTime);
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireManager(tx, actorId, estateId);
        const facility = await tx.estateFacility.create({ data: {
          estateId, createdById: actorId, code: input.code.trim().toUpperCase(), name: input.name.trim(),
          category: input.category.trim().toLowerCase(), description: input.description.trim(), location: input.location.trim(),
          capacity: input.capacity, durationMinutes: input.durationMinutes, openingTime: input.openingTime,
          closingTime: input.closingTime, bookingLeadHours: input.bookingLeadHours,
        } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'facility.created', targetType: 'estate_facility', targetId: facility.id, outcome: 'success', occurredAt: facility.createdAt, metadata: { code: facility.code, policyVersion: facility.policyVersion } } });
        return this.facilityView(facility);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('A facility with this code already exists in the estate.');
      throw error;
    }
  }

  async availability(actorId: string, estateId: string, facilityId: string, date: string) {
    this.validateDate(date);
    await this.requireFacilityRead(actorId, estateId);
    const facility = await this.prisma.estateFacility.findFirst({ where: { id: facilityId, estateId, active: true } });
    if (!facility) throw new NotFoundException('Facility not found.');
    const dayStart = this.localTime(date, '00:00');
    const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
    const booked = await this.prisma.estateFacilityBooking.findMany({ where: { facilityId, status: 'CONFIRMED', startsAt: { lt: dayEnd }, endsAt: { gt: dayStart } }, select: { startsAt: true, endsAt: true } });
    const [openHour, openMinute] = facility.openingTime.split(':').map(Number);
    const [closeHour, closeMinute] = facility.closingTime.split(':').map(Number);
    const opening = openHour * 60 + openMinute;
    const closing = closeHour * 60 + closeMinute;
    const items: { startsAt: string; endsAt: string; remainingCapacity: number; policyVersion: number }[] = [];
    const now = Date.now();
    for (let minute = opening; minute + facility.durationMinutes <= closing; minute += facility.durationMinutes) {
      const startLabel = `${String(Math.floor(minute / 60)).padStart(2, '0')}:${String(minute % 60).padStart(2, '0')}`;
      const endMinute = minute + facility.durationMinutes;
      const endLabel = `${String(Math.floor(endMinute / 60)).padStart(2, '0')}:${String(endMinute % 60).padStart(2, '0')}`;
      const startsAt = this.localTime(date, startLabel);
      const endsAt = this.localTime(date, endLabel);
      if (startsAt.getTime() < now + facility.bookingLeadHours * 3600000) continue;
      if (booked.some((booking) => booking.startsAt < endsAt && booking.endsAt > startsAt)) continue;
      items.push({ startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString(), remainingCapacity: 1, policyVersion: facility.policyVersion });
    }
    return { estateId, facilityId, date, timezone: 'Africa/Lagos', policyVersion: facility.policyVersion, asOf: new Date().toISOString(), items };
  }

  async createBooking(actorId: string, estateId: string, facilityId: string, input: CreateFacilityBookingDto, idempotencyKey: string | undefined) {
    if (!idempotencyKey || idempotencyKey.length < 8 || idempotencyKey.length > 128) throw new BadRequestException('A valid Idempotency-Key header is required.');
    const startsAt = new Date(input.startsAt); const endsAt = new Date(input.endsAt);
    if (!Number.isFinite(startsAt.valueOf()) || !Number.isFinite(endsAt.valueOf()) || endsAt <= startsAt) throw new BadRequestException('Provide a valid booking start and end time.');
    const keyHash = digest(`estate-facility-booking:v1:${idempotencyKey}`);
    const payloadHash = digest(JSON.stringify({ estateId, facilityId, propertyId: input.propertyId, startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString(), attendeeCount: input.attendeeCount, purpose: input.purpose?.trim() ?? '', acceptedPolicyVersion: input.acceptedPolicyVersion }));
    try {
      return await this.prisma.$transaction(async (tx) => {
        const prior = await tx.estateFacilityBooking.findUnique({ where: { requesterUserId_estateId_idempotencyKeyHash: { requesterUserId: actorId, estateId, idempotencyKeyHash: keyHash } } });
        if (prior) {
          if (prior.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was already used with different booking details.');
          await this.requirePropertyRelationship(tx, actorId, estateId, prior.propertyId, prior.startsAt, prior.endsAt);
          return this.bookingView(prior, true);
        }
        const facility = await tx.estateFacility.findFirst({ where: { id: facilityId, estateId, active: true } });
        if (!facility) throw new NotFoundException('Facility not found.');
        if (facility.policyVersion !== input.acceptedPolicyVersion) throw new ConflictException('The facility policy changed. Reload the booking details and accept the current policy.');
        if (input.attendeeCount > facility.capacity) throw new BadRequestException('Attendee count exceeds this facility\'s capacity.');
        this.validateBookingWindow(facility, startsAt, endsAt);
        await this.requirePropertyRelationship(tx, actorId, estateId, input.propertyId, startsAt, endsAt);
        const confirmedConflict = await tx.estateFacilityBooking.findFirst({ where: { facilityId, status: 'CONFIRMED', startsAt: { lt: endsAt }, endsAt: { gt: startsAt } }, select: { id: true } });
        if (confirmedConflict) throw new ConflictException('That facility time has already been confirmed. Choose another available slot.');
        const createdAt = new Date();
        const bookingId = randomUUID();
        const booking = await tx.estateFacilityBooking.create({ data: {
          id: bookingId, reference: `FAC-${bookingId.replaceAll('-', '').slice(0, 10).toUpperCase()}`,
          estateId, facilityId, propertyId: input.propertyId, requesterUserId: actorId, startsAt, endsAt,
          attendeeCount: input.attendeeCount, purpose: input.purpose?.trim() || null,
          policyVersion: facility.policyVersion, status: 'PENDING_REVIEW', idempotencyKeyHash: keyHash, payloadHash,
          history: { create: { actorUserId: actorId, fromStatus: null, toStatus: 'PENDING_REVIEW', occurredAt: createdAt } },
        } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'facility_booking.requested', targetType: 'estate_facility_booking', targetId: booking.id, outcome: 'success', occurredAt: createdAt, metadata: { facilityId, propertyId: input.propertyId, policyVersion: facility.policyVersion } } });
        return { ...this.bookingView(booking), status: booking.status.toLowerCase(), notice: 'Request submitted for staff review. It does not reserve the facility until confirmed.' };
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      const code = (error as { code?: string }).code;
      if (code === 'P2002') {
        const previous = await this.prisma.estateFacilityBooking.findUnique({ where: { requesterUserId_estateId_idempotencyKeyHash: { requesterUserId: actorId, estateId, idempotencyKeyHash: keyHash } } });
        if (previous) {
          if (previous.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was already used with different booking details.');
          await this.requirePropertyRelationship(this.prisma, actorId, estateId, previous.propertyId, previous.startsAt, previous.endsAt);
          return this.bookingView(previous, true);
        }
        throw new ConflictException('This booking request conflicts with an existing request.');
      }
      if (code === 'P2034') throw new ConflictException('Facility availability changed while submitting. Reload and try again.');
      throw error;
    }
  }

  async mine(actorId: string, estateId: string) {
    const memberships = await this.prisma.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!memberships) throw new ForbiddenException('Active estate membership is required.');
    const bookings = await this.prisma.estateFacilityBooking.findMany({ where: { estateId, requesterUserId: actorId }, include: { facility: { select: { name: true } }, property: { select: { code: true } } }, orderBy: { startsAt: 'desc' }, take: 100 });
    return { estateId, items: bookings.map((booking) => ({ ...this.bookingView(booking), facilityName: booking.facility.name, propertyCode: booking.property.code })) };
  }

  async queue(actorId: string, estateId: string) {
    await this.requireManager(this.prisma, actorId, estateId);
    const rows = await this.prisma.estateFacilityBooking.findMany({ where: { estateId }, include: { facility: { select: { name: true } }, property: { select: { code: true } }, requester: { select: { displayName: true } } }, orderBy: { createdAt: 'desc' }, take: 100 });
    return { estateId, items: rows.map((row) => ({ ...this.bookingView(row), facilityName: row.facility.name, propertyCode: row.property.code, requesterName: row.requester.displayName })) };
  }

  async review(actorId: string, estateId: string, bookingId: string, input: ReviewFacilityBookingDto) {
    if (input.command === 'decline' && !input.reason?.trim()) throw new BadRequestException('A reason is required when declining a booking.');
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireManager(tx, actorId, estateId);
        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_facility_bookings WHERE id = ${bookingId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const booking = await tx.estateFacilityBooking.findFirst({ where: { id: bookingId, estateId }, include: { facility: true } });
        if (!booking) throw new NotFoundException('Facility booking not found.');
        if (booking.status !== 'PENDING_REVIEW') throw new ConflictException('Only pending facility requests can be reviewed.');
        if (input.command === 'confirm') {
          await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_facilities WHERE id = ${booking.facilityId}::uuid FOR UPDATE`;
          const currentFacility = await tx.estateFacility.findUnique({ where: { id: booking.facilityId } });
          if (!currentFacility) throw new NotFoundException('Facility not found.');
          if (!currentFacility.active || booking.policyVersion !== currentFacility.policyVersion) throw new ConflictException('Facility policy changed after this request; decline it and ask the resident to submit again.');
          this.validateBookingWindow({ ...currentFacility, bookingLeadHours: 0 }, booking.startsAt, booking.endsAt);
          await this.requirePropertyRelationship(tx, booking.requesterUserId, estateId, booking.propertyId, booking.startsAt, booking.endsAt);
          const conflict = await tx.estateFacilityBooking.findFirst({ where: { facilityId: booking.facilityId, id: { not: booking.id }, status: 'CONFIRMED', startsAt: { lt: booking.endsAt }, endsAt: { gt: booking.startsAt } }, select: { id: true } });
          if (conflict) throw new ConflictException('Another booking has already been confirmed for this time.');
        }
        const status = input.command === 'confirm' ? 'CONFIRMED' : 'DECLINED';
        const at = new Date();
        const updated = await tx.estateFacilityBooking.update({ where: { id: booking.id }, data: { status, reviewerUserId: actorId, reviewedAt: at, reviewReason: input.reason?.trim() || null } });
        await tx.estateFacilityBookingHistory.create({ data: { bookingId: booking.id, actorUserId: actorId, fromStatus: booking.status, toStatus: status, reason: input.reason?.trim() || null, occurredAt: at } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: `facility_booking.${input.command === 'confirm' ? 'confirmed' : 'declined'}`, targetType: 'estate_facility_booking', targetId: booking.id, outcome: 'success', reason: input.reason?.trim() || null, occurredAt: at, metadata: { facilityId: booking.facilityId } } });
        return this.bookingView(updated);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2034') throw new ConflictException('Facility availability changed during review. Reload the queue and try again.');
      throw error;
    }
  }

  async cancel(actorId: string, estateId: string, bookingId: string) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_facility_bookings WHERE id = ${bookingId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const booking = await tx.estateFacilityBooking.findFirst({ where: { id: bookingId, estateId, requesterUserId: actorId }, select: { id: true, reference: true, facilityId: true, propertyId: true, requesterUserId: true, startsAt: true, endsAt: true, attendeeCount: true, purpose: true, policyVersion: true, status: true, createdAt: true } });
        if (!booking) throw new NotFoundException('Facility booking not found.');
        if (booking.status === 'CANCELLED') return this.bookingView(booking, true);
        if (!['PENDING_REVIEW', 'CONFIRMED'].includes(booking.status)) throw new ConflictException('Only pending or confirmed bookings can be cancelled.');
        if (booking.startsAt <= new Date()) throw new ConflictException('A booking cannot be cancelled after its start time.');
        const at = new Date();
        const updated = await tx.estateFacilityBooking.update({ where: { id: booking.id }, data: { status: 'CANCELLED' } });
        await tx.estateFacilityBookingHistory.create({ data: { bookingId: booking.id, actorUserId: actorId, fromStatus: booking.status, toStatus: 'CANCELLED', reason: 'Cancelled by the resident.', occurredAt: at } });
        await tx.auditEvent.create({ data: { actorUserId: actorId, scope: 'estate', estateId, action: 'facility_booking.cancelled', targetType: 'estate_facility_booking', targetId: booking.id, outcome: 'success', occurredAt: at, metadata: { facilityId: booking.facilityId } } });
        return this.bookingView(updated);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2034') throw new ConflictException('The booking changed while cancelling. Reload and try again.');
      throw error;
    }
  }

  private async requireFacilityRead(actorId: string, estateId: string) {
    const [manager, member, relation] = await Promise.all([
      this.prisma.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', role: { in: [...MANAGERS] }, estate: { status: 'ACTIVE' } }, select: { id: true } }),
      this.prisma.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' } }, select: { id: true } }),
      this.hasAnyCurrentPropertyRelationship(this.prisma, actorId, estateId),
    ]);
    if (!manager && !(member && relation)) throw new ForbiddenException('Active estate property access is required to view facilities.');
  }

  private async hasAnyCurrentPropertyRelationship(tx: Prisma.TransactionClient | PrismaService, actorId: string, estateId: string) {
    const today = new Date();
    const window = { effectiveFrom: { lte: today }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }] };
    const [occupancy, tenancy, ownership] = await Promise.all([
      tx.propertyOccupancy.findFirst({ where: { estateId, residentId: actorId, status: 'ACTIVE', ...window }, select: { id: true } }),
      tx.estateTenancy.findFirst({ where: { estateId, tenantUserId: actorId, status: 'ACTIVE', ...window }, select: { id: true } }),
      tx.estateOwnershipInterest.findFirst({ where: { estateId, ownerUserId: actorId, status: 'ACTIVE', verificationStatus: 'VERIFIED', ...window }, select: { id: true } }),
    ]);
    return Boolean(occupancy || tenancy || ownership);
  }

  private async requirePropertyRelationship(tx: Prisma.TransactionClient | PrismaService, actorId: string, estateId: string, propertyId: string, startsAt: Date, endsAt: Date) {
    const membership = await tx.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate membership is required to request a facility booking.');
    const property = await tx.estateProperty.findFirst({ where: { id: propertyId, estateId, status: { not: 'ARCHIVED' } }, select: { id: true } });
    if (!property) throw new NotFoundException('Property not found.');
    const window = { effectiveFrom: { lte: startsAt }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: endsAt } }] };
    const [occupancy, tenancy, ownership] = await Promise.all([
      tx.propertyOccupancy.findFirst({ where: { estateId, propertyId, residentId: actorId, status: 'ACTIVE', ...window }, select: { id: true } }),
      tx.estateTenancy.findFirst({ where: { estateId, propertyId, tenantUserId: actorId, status: 'ACTIVE', ...window }, select: { id: true } }),
      tx.estateOwnershipInterest.findFirst({ where: { estateId, propertyId, ownerUserId: actorId, status: 'ACTIVE', verificationStatus: 'VERIFIED', ...window }, select: { id: true } }),
    ]);
    if (!occupancy && !tenancy && !ownership) throw new ForbiddenException('An active approved relationship with this property is required for the requested time.');
  }

  private async requireManager(tx: Prisma.TransactionClient | PrismaService, actorId: string, estateId: string) {
    const membership = await tx.estateMembership.findFirst({ where: { userId: actorId, estateId, status: 'ACTIVE', role: { in: [...MANAGERS] }, estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate facility management access is required.');
  }

  private facilityView(item: any) {
    return { id: item.id, estateId: item.estateId, code: item.code, name: item.name, category: item.category, description: item.description, location: item.location, capacity: item.capacity, durationMinutes: item.durationMinutes, openingTime: item.openingTime, closingTime: item.closingTime, bookingLeadHours: item.bookingLeadHours, approvalMode: item.approvalMode.toLowerCase(), policyVersion: item.policyVersion };
  }

  private bookingView(item: any, replayed = false) {
    return { id: item.id, reference: item.reference, estateId: item.estateId, facilityId: item.facilityId, propertyId: item.propertyId, startsAt: item.startsAt.toISOString(), endsAt: item.endsAt.toISOString(), attendeeCount: item.attendeeCount, purpose: item.purpose, policyVersion: item.policyVersion, status: item.status.toLowerCase(), createdAt: item.createdAt.toISOString(), replayed };
  }

  private validateBookingWindow(facility: { durationMinutes: number; openingTime: string; closingTime: string; bookingLeadHours: number }, startsAt: Date, endsAt: Date) {
    if (endsAt.getTime() - startsAt.getTime() !== facility.durationMinutes * 60000) throw new BadRequestException(`This facility allows bookings of ${facility.durationMinutes} minutes.`);
    if (startsAt.getTime() < Date.now() + facility.bookingLeadHours * 3600000 || startsAt.getTime() > Date.now() + 90 * 86400000) throw new BadRequestException('Choose a booking time within the permitted lead window.');
    const start = this.lagosParts(startsAt); const end = this.lagosParts(new Date(endsAt.getTime() - 1));
    if (start.date !== end.date || start.date !== this.lagosParts(endsAt).date) throw new BadRequestException('Bookings must start and end on the same estate-local date.');
    const startMinute = start.hour * 60 + start.minute; const endMinute = this.lagosParts(endsAt).hour * 60 + this.lagosParts(endsAt).minute;
    const opening = this.minutes(facility.openingTime); const closing = this.minutes(facility.closingTime);
    if (startMinute < opening || endMinute > closing) throw new BadRequestException('The requested time is outside facility opening hours.');
  }

  private validateHours(opening: string, closing: string) { if (this.minutes(closing) <= this.minutes(opening)) throw new BadRequestException('Facility closing time must be after opening time on the same day.'); }
  private minutes(value: string) { const [hour, minute] = value.split(':').map(Number); return hour * 60 + minute; }
  private localTime(date: string, time: string) { return new Date(`${date}T${time}:00+01:00`); }
  private validateDate(value: string) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new BadRequestException('Provide a date in YYYY-MM-DD format.');
    const date = new Date(`${value}T00:00:00.000Z`);
    if (Number.isNaN(date.valueOf()) || date.toISOString().slice(0, 10) !== value) throw new BadRequestException('Provide a valid date in YYYY-MM-DD format.');
    const today = this.lagosParts(new Date()).date;
    const latest = new Date(`${today}T00:00:00.000Z`);
    latest.setUTCDate(latest.getUTCDate() + 90);
    if (value < today || value > latest.toISOString().slice(0, 10)) throw new BadRequestException('Availability can be checked for today through the next 90 days.');
  }
  private lagosParts(value: Date) { const parts = new Intl.DateTimeFormat('en-GB', { timeZone: 'Africa/Lagos', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(value); const get = (type: string) => parts.find((part) => part.type === type)?.value ?? '0'; return { date: `${get('year')}-${get('month')}-${get('day')}`, hour: Number(get('hour')), minute: Number(get('minute')) }; }
}
