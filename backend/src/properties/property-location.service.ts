import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, type EstateRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CapturePropertyLocationDto, VerifyPropertyLocationDto } from './property-location.dto.js';

const MANAGEMENT_ROLES: EstateRole[] = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'FINANCE_MANAGER'];

@Injectable()
export class PropertyLocationService {
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

  private view(property: any, showCoordinates: boolean) {
    const verified = property.locationVerificationStatus === 'VERIFIED';
    const canShow = showCoordinates || verified;
    return {
      id: property.id, estateId: property.estateId, code: property.code,
      propertyType: property.propertyType, unitNumber: property.unitNumber,
      propertyStatus: property.status,
      latitude: canShow ? property.latitude?.toString() ?? null : null,
      longitude: canShow ? property.longitude?.toString() ?? null : null,
      accuracyMeters: canShow ? property.locationAccuracyMeters?.toString() ?? null : null,
      captureMethod: property.locationCaptureMethod,
      capturedAt: property.locationCapturedAt?.toISOString() ?? null,
      verificationStatus: property.locationVerificationStatus.toLowerCase(),
      verifiedAt: property.locationVerifiedAt?.toISOString() ?? null,
      correctionReason: property.locationCorrectionReason,
    };
  }

  async list(actorUserId: string, estateId: string) {
    const membership = await this.membership(actorUserId, estateId);
    const isManager = MANAGEMENT_ROLES.includes(membership.role);
    const properties = await this.prisma.estateProperty.findMany({
      where: { estateId, status: { not: 'ARCHIVED' } },
      select: {
        id: true, estateId: true, code: true, propertyType: true, unitNumber: true, status: true,
        latitude: true, longitude: true, locationAccuracyMeters: true, locationCaptureMethod: true,
        locationCapturedAt: true, locationVerificationStatus: true, locationVerifiedAt: true,
        locationCorrectionReason: true,
      },
      orderBy: { code: 'asc' }, take: 300,
    });
    return { items: properties.map((property) => this.view(property, isManager)) };
  }

  async capture(actorUserId: string, estateId: string, propertyId: string, input: CapturePropertyLocationDto) {
    return this.prisma.$transaction(async (tx) => {
      await this.membership(actorUserId, estateId, true);
      await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_properties WHERE id = ${propertyId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
      const property = await tx.estateProperty.findFirst({
        where: { id: propertyId, estateId, status: { not: 'ARCHIVED' } },
        select: { id: true },
      });
      if (!property) throw new NotFoundException('Property not found in this estate.');
      const updated = await tx.estateProperty.update({
        where: { id: propertyId },
        data: {
          latitude: new Prisma.Decimal(input.latitude),
          longitude: new Prisma.Decimal(input.longitude),
          locationAccuracyMeters: input.accuracyMeters === undefined ? null : new Prisma.Decimal(input.accuracyMeters),
          locationCaptureMethod: input.captureMethod,
          locationCapturedAt: new Date(),
          locationVerificationStatus: 'PENDING_VERIFICATION',
          locationVerifiedById: null,
          locationVerifiedAt: null,
          locationCorrectionReason: input.reason?.trim() || null,
        },
      });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'property.location_captured',
        targetType: 'estate_property', targetId: propertyId, outcome: 'success', occurredAt: new Date(),
        metadata: { latitude: input.latitude, longitude: input.longitude, captureMethod: input.captureMethod },
      } });
      return this.view(updated, true);
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async verify(actorUserId: string, estateId: string, propertyId: string, input: VerifyPropertyLocationDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.membership(actorUserId, estateId, true);
        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_properties WHERE id = ${propertyId}::uuid AND estate_id = ${estateId}::uuid FOR UPDATE`;
        const property = await tx.estateProperty.findFirst({
          where: { id: propertyId, estateId, status: { not: 'ARCHIVED' } },
          select: { id: true, latitude: true, longitude: true, locationVerificationStatus: true },
        });
        if (!property) throw new NotFoundException('Property not found in this estate.');
        if (property.latitude === null || property.longitude === null) {
          throw new BadRequestException('Capture a property location before verifying it.');
        }
        if (property.locationVerificationStatus !== 'PENDING_VERIFICATION') {
          throw new ConflictException('Only a pending property location can be verified or rejected.');
        }
        if (input.decision === 'reject' && !input.reason?.trim()) {
          throw new BadRequestException('A reason is required when rejecting a property location.');
        }
        const updated = await tx.estateProperty.update({
          where: { id: propertyId },
          data: {
            locationVerificationStatus: input.decision === 'verify' ? 'VERIFIED' : 'REJECTED',
            locationVerifiedById: actorUserId,
            locationVerifiedAt: new Date(),
            locationCorrectionReason: input.reason?.trim() || null,
          },
        });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: input.decision === 'verify' ? 'property.location_verified' : 'property.location_rejected',
          targetType: 'estate_property', targetId: propertyId, outcome: 'success', occurredAt: new Date(),
          metadata: { decision: input.decision },
        } });
        return this.view(updated, true);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    } catch (error) {
      if (['P2002', 'P2034'].includes((error as { code?: string })?.code ?? '')) {
        throw new ConflictException('This property location changed during review. Reload and try again.');
      }
      throw error;
    }
  }
}

