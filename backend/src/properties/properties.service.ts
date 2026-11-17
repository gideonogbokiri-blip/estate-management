import {
  ConflictException,
  ForbiddenException,
  BadRequestException,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Prisma, PropertyStatus } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { validatePropertyDraft } from '../../modules/properties/property.js';
import type {
  PropertyDraftDto,
  PropertyQueryDto,
  UpdatePropertyDto,
} from './properties.dto.js';
import type { StructureNodeDraftDto, UpdateStructureNodeDto } from './structure.dto.js';
import type { CreateResidentJoinRequestDto, ResidentJoinRequestQueryDto } from './resident-requests.dto.js';
import { StructureError, StructureNodeTypes, validateStructureNodeDraft } from '../../modules/properties/structure.js';

const { createPropertyArchiveUseCase } = require('../../modules/properties/archive-property.js') as { createPropertyArchiveUseCase: (ports: any) => (input: any) => Promise<any> };

const MANAGER_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER'] as const;
const STATUS_TO_DB: Record<string, PropertyStatus> = {
  active: PropertyStatus.ACTIVE,
  under_development: PropertyStatus.UNDER_DEVELOPMENT,
  reserved: PropertyStatus.RESERVED,
  under_maintenance: PropertyStatus.UNDER_MAINTENANCE,
  inactive: PropertyStatus.INACTIVE,
};
const STRUCTURE_TYPES = { zone: 'ZONE', street: 'STREET', building: 'BUILDING', floor: 'FLOOR' } as const;
const STRUCTURE_STATUSES = { ACTIVE: 'active', ARCHIVED: 'archived' } as const;

@Injectable()
export class PropertiesService {
  constructor(private readonly prisma: PrismaService) {}

  async listAvailableEstates() {
    const estates = await this.prisma.estate.findMany({
      where: { status: 'ACTIVE' }, orderBy: { name: 'asc' }, take: 200,
      select: { id: true, estateCode: true, name: true, estateType: true, state: true, lga: true },
    });
    return { items: estates };
  }

  async listJoinRequestProperties(estateId: string) {
    const estate = await this.prisma.estate.findFirst({ where: { id: estateId, status: 'ACTIVE' }, select: { id: true } });
    if (!estate) throw new NotFoundException('Active estate not found.');
    const properties = await this.prisma.estateProperty.findMany({
      where: { estateId, status: { not: 'ARCHIVED' } },
      orderBy: [{ code: 'asc' }], take: 200,
      select: { id: true, code: true, propertyType: true, unitNumber: true, structureLinks: { select: { node: { select: { name: true, type: true } } } } },
    });
    return { items: properties.map((property) => ({
      id: property.id, code: property.code, propertyType: property.propertyType, unitNumber: property.unitNumber,
      structure: property.structureLinks.map((link) => ({ name: link.node.name, type: link.node.type.toLowerCase() })),
    })) };
  }

  async listMyEstates(actorUserId: string) {
    const memberships = await this.prisma.estateMembership.findMany({
      where: {
        userId: actorUserId,
        status: 'ACTIVE',
        estate: { status: 'ACTIVE' },
      },
      orderBy: [{ estate: { name: 'asc' } }, { createdAt: 'asc' }],
      select: {
        role: true,
        estate: {
          select: {
            id: true,
            estateCode: true,
            name: true,
            estateType: true,
            address: true,
            state: true,
            lga: true,
          },
        },
      },
    });
    const estates = new Map<string, {
      id: string;
      estateCode: string;
      name: string;
      estateType: string;
      address: string;
      state: string;
      lga: string;
      roles: string[];
    }>();
    for (const membership of memberships) {
      const estate = estates.get(membership.estate.id) ?? {
        ...membership.estate,
        roles: [],
      };
      estate.roles.push(membership.role.toLowerCase());
      estates.set(estate.id, estate);
    }
    return { items: [...estates.values()] };
  }

  async listMyManagementEstates(actorUserId: string) {
    const rows = await this.prisma.estateMembership.findMany({
      where: { userId: actorUserId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES, 'FINANCE_MANAGER'] }, estate: { status: 'ACTIVE' } },
      orderBy: { estate: { name: 'asc' } },
      select: { role: true, estate: { select: { id: true, estateCode: true, name: true, address: true, state: true, lga: true } } },
      take: 200,
    });
    const byEstate = new Map<string, { id: string; name: string; location: string; roles: string[] }>();
    for (const row of rows) {
      const estate = byEstate.get(row.estate.id) ?? { id: row.estate.id, name: row.estate.name, location: [row.estate.address, row.estate.lga, row.estate.state].filter(Boolean).join(', '), roles: [] };
      estate.roles.push(row.role.toLowerCase());
      byEstate.set(row.estate.id, estate);
    }
    return { items: [...byEstate.values()] };
  }

  async list(actorUserId: string, estateId: string, query: PropertyQueryDto) {
    await this.requireManager(actorUserId, estateId);
    const where: Prisma.EstatePropertyWhereInput = {
      estateId,
      ...(query.status ? { status: STATUS_TO_DB[query.status] } : {}),
      ...(query.search?.trim()
        ? {
            OR: [
              { code: { contains: query.search.trim(), mode: 'insensitive' } },
              { propertyType: { contains: query.search.trim(), mode: 'insensitive' } },
              { unitNumber: { contains: query.search.trim(), mode: 'insensitive' } },
              { address: { contains: query.search.trim(), mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [records, total] = await this.prisma.$transaction([
      this.prisma.estateProperty.findMany({
        where,
        include: { structureLinks: { include: { node: { select: { id: true, type: true, name: true, code: true } } } } },
        orderBy: [{ code: 'asc' }, { createdAt: 'asc' }],
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
      }),
      this.prisma.estateProperty.count({ where }),
    ]);
    return {
      items: records.map((record) => this.toResponse(record)),
      page: query.page,
      pageSize: query.pageSize,
      total,
    };
  }

  async create(actorUserId: string, estateId: string, dto: PropertyDraftDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireManager(actorUserId, estateId, tx);
        const structureNodeIds = dto.structureNodeIds ?? [];
        const parents = await this.resolveStructureNodes(tx, estateId, structureNodeIds);
        const draft = this.validate({ ...dto, status: dto.status ?? 'active', estateId }, parents);
        const duplicate = await tx.estateProperty.findFirst({
          where: { estateId, code: { equals: draft.code, mode: 'insensitive' } },
          select: { id: true },
        });
        if (duplicate) throw new ConflictException('A property with this code already exists in this estate.');
        const now = new Date();
        const property = await tx.estateProperty.create({
          data: {
            estateId,
            code: draft.code.toLocaleUpperCase('en'),
            propertyType: draft.propertyType,
            status: STATUS_TO_DB[draft.status],
            unitNumber: draft.unitNumber,
            address: draft.address,
            description: draft.description,
            latitude: draft.latitude,
            longitude: draft.longitude,
            createdByUserId: actorUserId,
            structureLinks: { create: structureNodeIds.map((nodeId) => ({ nodeId })) },
          },
          include: { structureLinks: { include: { node: { select: { id: true, type: true, name: true, code: true } } } } },
        });
        await tx.auditEvent.create({
          data: {
            actorUserId,
            scope: 'estate',
            estateId,
            action: 'property.created',
            targetType: 'property',
            targetId: property.id,
            outcome: 'success',
            occurredAt: now,
          },
        });
        return this.toResponse(property);
      });
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        throw new ConflictException('A property with this code already exists in this estate.');
      }
      throw error;
    }
  }

  async update(
    actorUserId: string,
    estateId: string,
    propertyId: string,
    dto: UpdatePropertyDto,
  ) {
    return this.prisma.$transaction(async (tx) => {
      await this.requireManager(actorUserId, estateId, tx);
      const current = await tx.estateProperty.findFirst({
        where: { id: propertyId, estateId }, include: { structureLinks: true },
      });
      if (!current) throw new NotFoundException('Property not found.');
      if (current.status === PropertyStatus.ARCHIVED) {
        throw new ConflictException('Archived properties cannot be edited.');
      }
      const structureNodeIds = dto.structureNodeIds ?? current.structureLinks.map((link) => link.nodeId);
      const parents = await this.resolveStructureNodes(tx, estateId, structureNodeIds);
      const draft = this.validate({
        ...current,
        ...dto,
        estateId,
        latitude: dto.latitude === undefined ? current.latitude?.toString() : dto.latitude,
        longitude: dto.longitude === undefined ? current.longitude?.toString() : dto.longitude,
        status: dto.status ?? current.status.toLowerCase(),
      }, parents);
      const normalizedCode = draft.code.toLocaleUpperCase('en');
      const duplicate = await tx.estateProperty.findFirst({
        where: {
          estateId,
          id: { not: propertyId },
          code: { equals: normalizedCode, mode: 'insensitive' },
        },
        select: { id: true },
      });
      if (duplicate) throw new ConflictException('A property with this code already exists in this estate.');
      const now = new Date();
      const changed = await tx.estateProperty.updateMany({
        where: { id: propertyId, estateId, status: current.status, updatedAt: current.updatedAt },
        data: {
          code: normalizedCode,
          propertyType: draft.propertyType,
          status: STATUS_TO_DB[draft.status],
          unitNumber: draft.unitNumber,
          address: draft.address,
          description: draft.description,
          latitude: draft.latitude,
          longitude: draft.longitude,
          updatedByUserId: actorUserId,
        },
      });
      if (changed.count !== 1) throw new ConflictException('Property changed. Reload and try again.');
      await tx.estatePropertyStructure.deleteMany({ where: { propertyId } });
      if (structureNodeIds.length) {
        await tx.estatePropertyStructure.createMany({ data: structureNodeIds.map((nodeId) => ({ propertyId, nodeId })) });
      }
      await tx.auditEvent.create({
        data: {
          actorUserId,
          scope: 'estate',
          estateId,
          action: 'property.updated',
          targetType: 'property',
          targetId: propertyId,
          outcome: 'success',
          occurredAt: now,
        },
      });
      const updated = await tx.estateProperty.findUniqueOrThrow({
        where: { id: propertyId },
        include: { structureLinks: { include: { node: { select: { id: true, type: true, name: true, code: true } } } } },
      });
      return this.toResponse(updated);
    });
  }

  async archiveProperty(actorUserId: string, estateId: string, propertyId: string) {
    const archive = createPropertyArchiveUseCase({
      transaction: async (work: (tx: Prisma.TransactionClient) => Promise<unknown>) => {
        for (let attempt = 0; ; attempt += 1) {
          try { return await this.prisma.$transaction(work, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }); }
          catch (error) { if ((error as { code?: string })?.code !== 'P2034' || attempt >= 2) throw error; }
        }
      },
      requireEstatePermission: async (actorId: string, requestedEstateId: string, _permission: string, tx: Prisma.TransactionClient) => {
        await this.requireManager(actorId, requestedEstateId, tx);
        return { estateId: requestedEstateId };
      },
      findPropertyForUpdate: async (tx: Prisma.TransactionClient, scope: { propertyId: string; estateContext: { estateId: string } }) => {
        await tx.$queryRaw`SELECT id FROM estate_properties WHERE id = ${scope.propertyId}::uuid AND estate_id = ${scope.estateContext.estateId}::uuid FOR UPDATE`;
        const property = await tx.estateProperty.findFirst({ where: { id: scope.propertyId, estateId: scope.estateContext.estateId }, select: { id: true, estateId: true, status: true, archivedAt: true } });
        return property ? { ...property, status: property.status.toLowerCase() } : null;
      },
      inspectArchiveRelationships: async (tx: Prisma.TransactionClient, scope: { property: { id: string; estateId: string } }) => {
        const now = new Date();
        const [occupancies, ownerships, tenancies, joinRequests, maintenance, passes, visits, chargeVersions] = await Promise.all([
          tx.propertyOccupancy.count({ where: { estateId: scope.property.estateId, propertyId: scope.property.id, status: 'ACTIVE', OR: [{ effectiveTo: null }, { effectiveTo: { gte: now } }] } }),
          tx.estateOwnershipInterest.count({ where: { estateId: scope.property.estateId, propertyId: scope.property.id, status: 'ACTIVE', OR: [{ effectiveTo: null }, { effectiveTo: { gte: now } }] } }),
          tx.estateTenancy.count({ where: { estateId: scope.property.estateId, propertyId: scope.property.id, status: { in: ['ACTIVE', 'PENDING_APPROVAL'] }, OR: [{ effectiveTo: null }, { effectiveTo: { gte: now } }] } }),
          tx.estateResidentJoinRequest.count({ where: { estateId: scope.property.estateId, propertyId: scope.property.id, status: 'PENDING' } }),
          tx.estateMaintenanceRequest.count({ where: { estateId: scope.property.estateId, propertyId: scope.property.id, status: { notIn: ['RESOLVED', 'CLOSED', 'REJECTED'] } } }),
          tx.estateVisitorPass.count({ where: { estateId: scope.property.estateId, propertyId: scope.property.id, revokedAt: null, validUntil: { gt: now } } }),
          tx.estateVisitorVisit.count({ where: { estateId: scope.property.estateId, propertyId: scope.property.id, status: 'checked_in', checkedOutAt: null } }),
          tx.estateChargeVersion.count({ where: { propertyId: scope.property.id, status: 'ACTIVE', OR: [{ effectiveTo: null }, { effectiveTo: { gte: now } }] } }),
        ]);
        const blockingRelationships = [
          ...(occupancies ? ['active_occupancies'] : []), ...(ownerships ? ['active_ownership_interests'] : []),
          ...(tenancies ? ['active_or_pending_tenancies'] : []), ...(joinRequests ? ['pending_resident_requests'] : []),
          ...(maintenance ? ['open_maintenance_requests'] : []), ...(passes ? ['unexpired_visitor_passes'] : []),
          ...(visits ? ['visitors_currently_inside'] : []), ...(chargeVersions ? ['active_property_charge_versions'] : []),
        ];
        return { complete: true, blockingRelationships };
      },
      commitArchive: async (tx: Prisma.TransactionClient, plan: any) => {
        const effect = plan.effects[0];
        const changed = await tx.estateProperty.updateMany({
          where: { id: effect.propertyId, estateId: effect.estateId, status: effect.from.toUpperCase() as PropertyStatus },
          data: { status: PropertyStatus.ARCHIVED, archivedAt: new Date(effect.archivedAt), updatedByUserId: effect.actorUserId },
        });
        if (changed.count !== 1) throw new ConflictException('Property changed while the archive was being confirmed. Reload and try again.');
        return { id: effect.propertyId, estateId: effect.estateId, status: 'archived' };
      },
      appendAuditEvent: async (tx: Prisma.TransactionClient, event: any) => tx.auditEvent.create({ data: {
        actorUserId: event.actorUserId, scope: event.scope, estateId: event.estateId, action: event.action,
        targetType: event.targetType, targetId: event.targetId, outcome: event.outcome, occurredAt: new Date(event.occurredAt),
      } }),
    });
    try {
      return await archive({ actorUserId, estateId, propertyId });
    } catch (error) {
      const code = (error as { code?: string })?.code;
      if (error instanceof ConflictException || error instanceof ForbiddenException || error instanceof NotFoundException) throw error;
      if (code === 'ACTIVE_RELATIONSHIPS' || code === 'ALREADY_ARCHIVED') throw new ConflictException((error as Error).message);
      if (code === 'ESTATE_ACCESS_DENIED') throw new ForbiddenException((error as Error).message);
      if (code === 'PROPERTY_NOT_FOUND') throw new NotFoundException((error as Error).message);
      throw error;
    }
  }

  async listStructure(actorUserId: string, estateId: string, includeArchived = false) {
    await this.requireManager(actorUserId, estateId);
    const nodes = await this.prisma.estateStructureNode.findMany({
      where: { estateId, ...(includeArchived ? {} : { status: 'ACTIVE' }) },
      include: {
        parents: { include: { parent: { select: { id: true, name: true, status: true } } } },
        _count: { select: { properties: true } },
      },
      orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    });
    return { items: nodes.map((node) => ({
      id: node.id, estateId, type: node.type.toLowerCase(), name: node.name, code: node.code,
      parentIds: node.parents.map((link) => link.parentId),
      parentNames: node.parents.map((link) => link.parent.name),
      buildingType: node.buildingType, floorCount: node.floorCount, sortOrder: node.sortOrder,
      linkedPropertyCount: node._count.properties, status: STRUCTURE_STATUSES[node.status],
    })), total: nodes.length };
  }

  async createStructureNode(actorUserId: string, estateId: string, dto: StructureNodeDraftDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireManager(actorUserId, estateId, tx);
        const parentIds = dto.parentIds ?? [];
        const parents = await tx.estateStructureNode.findMany({ where: { estateId, id: { in: parentIds }, status: 'ACTIVE' } });
        const draft = this.validateStructure({ ...dto, parentIds }, estateId, parents);
        if (draft.code) {
          const duplicate = await tx.estateStructureNode.findFirst({
            where: { estateId, type: STRUCTURE_TYPES[draft.type as keyof typeof STRUCTURE_TYPES], code: { equals: draft.code, mode: 'insensitive' } },
            select: { id: true },
          });
          if (duplicate) throw new ConflictException('That structure code is already in use in this estate.');
        }
        const createdAt = new Date();
        const node = await tx.estateStructureNode.create({ data: {
          estateId, type: STRUCTURE_TYPES[draft.type as keyof typeof STRUCTURE_TYPES], name: draft.name,
          code: draft.code, buildingType: draft.buildingType, floorCount: draft.floorCount, sortOrder: draft.sortOrder,
          createdById: actorUserId,
          parents: { create: parentIds.map((parentId) => ({ parentId })) },
        } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: 'estate_structure_node.created',
          targetType: 'estate_structure_node', targetId: node.id, outcome: 'success', occurredAt: createdAt,
        } });
        return this.structureResponse(node, parentIds);
      });
    } catch (error) {
      if (this.isUniqueViolation(error)) throw new ConflictException('That structure code is already in use in this estate.');
      throw error;
    }
  }

  async updateStructureNode(actorUserId: string, estateId: string, nodeId: string, dto: UpdateStructureNodeDto) {
    return this.prisma.$transaction(async (tx) => {
      await this.requireManager(actorUserId, estateId, tx);
      const current = await tx.estateStructureNode.findFirst({ where: { id: nodeId, estateId }, include: { parents: true } });
      if (!current) throw new NotFoundException('Structure node not found.');
      if (current.status !== 'ACTIVE') throw new ConflictException('Archived structure nodes cannot be edited.');
      const parentIds = dto.parentIds ?? current.parents.map((link) => link.parentId);
      if (parentIds.includes(nodeId)) throw new BadRequestException('A structure node cannot be its own parent.');
      const parents = await tx.estateStructureNode.findMany({ where: { estateId, id: { in: parentIds }, status: 'ACTIVE' } });
      const draft = this.validateStructure({
        type: current.type.toLowerCase(), name: dto.name ?? current.name, code: dto.code === undefined ? current.code : dto.code,
        parentIds, buildingType: dto.buildingType === undefined ? current.buildingType : dto.buildingType,
        floorCount: dto.floorCount === undefined ? current.floorCount ?? undefined : dto.floorCount,
        sortOrder: dto.sortOrder ?? current.sortOrder,
      }, estateId, parents);
      this.validateExistingChildren(current.type, draft.type, await tx.estateStructureNode.findMany({
        where: { parents: { some: { parentId: nodeId } }, status: 'ACTIVE' }, select: { type: true },
      }));
      if (draft.code && draft.code.toLowerCase() !== current.code?.toLowerCase()) {
        const duplicate = await tx.estateStructureNode.findFirst({ where: {
          estateId, id: { not: nodeId }, type: current.type,
          code: { equals: draft.code, mode: 'insensitive' },
        }, select: { id: true } });
        if (duplicate) throw new ConflictException('That structure code is already in use in this estate.');
      }
      const changedAt = new Date();
      const updated = await tx.estateStructureNode.update({ where: { id: nodeId }, data: {
        name: draft.name, code: draft.code, buildingType: draft.buildingType, floorCount: draft.floorCount,
        sortOrder: draft.sortOrder, updatedById: actorUserId,
        ...(dto.parentIds !== undefined ? { parents: { deleteMany: {}, create: parentIds.map((parentId) => ({ parentId })) } } : {}),
      } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'estate_structure_node.updated',
        targetType: 'estate_structure_node', targetId: nodeId, outcome: 'success', occurredAt: changedAt,
        metadata: { changedFields: Object.keys(dto).sort() },
      } });
      return this.structureResponse(updated, parentIds);
    });
  }

  async archiveStructureNode(actorUserId: string, estateId: string, nodeId: string) {
    return this.prisma.$transaction(async (tx) => {
      await this.requireManager(actorUserId, estateId, tx);
      const current = await tx.estateStructureNode.findFirst({ where: { id: nodeId, estateId } });
      if (!current) throw new NotFoundException('Structure node not found.');
      if (current.status !== 'ACTIVE') throw new ConflictException('Only active structure nodes can be archived.');
      const [children, properties] = await Promise.all([
        tx.estateStructureParent.count({ where: { parentId: nodeId, child: { status: 'ACTIVE' } } }),
        tx.estatePropertyStructure.count({ where: { nodeId, property: { status: { not: 'ARCHIVED' } } } }),
      ]);
      if (children || properties) throw new ConflictException('Move or archive linked properties and child structure nodes first.');
      const archivedAt = new Date();
      await tx.estateStructureNode.update({ where: { id: nodeId }, data: { status: 'ARCHIVED', archivedAt, updatedById: actorUserId } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'estate_structure_node.archive',
        targetType: 'estate_structure_node', targetId: nodeId, outcome: 'success', occurredAt: archivedAt,
      } });
      return { id: nodeId, estateId, status: 'archived' };
    });
  }

  async createResidentJoinRequest(actorUserId: string, dto: CreateResidentJoinRequestDto) {
    const propertyId = dto.propertyId || null;
    const relationship = dto.relationship?.toUpperCase() as 'OWNER' | 'TENANT' | 'HOUSEHOLD_MEMBER' | 'AUTHORIZED_OCCUPANT' | undefined;
    if ((propertyId === null) !== (relationship === undefined)) {
      throw new BadRequestException('A property and relationship must be provided together.');
    }
    try {
      return await this.prisma.$transaction(async (tx) => {
        const estate = await tx.estate.findFirst({ where: { id: dto.estateId, status: 'ACTIVE' }, select: { id: true, name: true } });
        if (!estate) throw new NotFoundException('Active estate not found.');
        if (propertyId) {
          const property = await tx.estateProperty.findFirst({ where: { id: propertyId, estateId: estate.id, status: { not: 'ARCHIVED' } }, select: { id: true } });
          if (!property) throw new NotFoundException('Active property not found in this estate.');
        }
        const existingMembership = await tx.estateMembership.findFirst({
          where: { estateId: estate.id, userId: actorUserId, role: 'RESIDENT', status: 'ACTIVE' }, select: { id: true },
        });
        if (existingMembership) throw new ConflictException('You already have active resident access to this estate.');
        const existingRequest = await tx.estateResidentJoinRequest.findFirst({
          where: { estateId: estate.id, applicantId: actorUserId, status: 'PENDING' }, select: { id: true },
        });
        if (existingRequest) throw new ConflictException('You already have a pending request for this estate.');
        const submittedAt = new Date();
        const created = await tx.estateResidentJoinRequest.create({ data: {
          estateId: estate.id, propertyId, applicantId: actorUserId, relationship: relationship ?? null,
          note: dto.note?.trim() || null, submittedAt,
        } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId: estate.id, action: 'resident.join_request.submitted',
          targetType: 'resident_join_request', targetId: created.id, outcome: 'success', occurredAt: submittedAt,
        } });
        return { id: created.id, estateId: estate.id, estateName: estate.name, propertyId, relationship: relationship?.toLowerCase() ?? null,
          note: created.note, status: 'pending', submittedAt };
      }, { isolationLevel: 'Serializable' });
    } catch (error) {
      if (this.isUniqueViolation(error)) throw new ConflictException('You already have a pending request for this estate.');
      if (typeof error === 'object' && error !== null && 'code' in error && (error as { code?: unknown }).code === 'P2034') {
        throw new ConflictException('Estate access changed while the request was being saved. Reload and try again.');
      }
      throw error;
    }
  }

  async listMyResidentJoinRequests(actorUserId: string, query: ResidentJoinRequestQueryDto) {
    const where = { applicantId: actorUserId, ...(query.status ? { status: query.status.toUpperCase() as 'PENDING' | 'APPROVED' | 'REJECTED' } : {}) };
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.estateResidentJoinRequest.findMany({
      where, orderBy: { submittedAt: 'desc' }, skip: (query.page - 1) * query.pageSize, take: query.pageSize,
      include: { estate: { select: { id: true, name: true, estateCode: true } }, property: { select: { id: true, code: true } } },
      }),
      this.prisma.estateResidentJoinRequest.count({ where }),
    ]);
    return { items: rows.map((row) => ({ id: row.id, estate: row.estate,
      property: row.property, relationship: row.relationship?.toLowerCase() ?? null,
      note: row.note, status: row.status.toLowerCase(), submittedAt: row.submittedAt,
      reviewedAt: row.reviewedAt, decisionReason: row.decisionReason })), page: query.page, pageSize: query.pageSize, total };
  }

  async listResidentJoinRequests(actorUserId: string, estateId: string, query: ResidentJoinRequestQueryDto) {
    await this.requireManager(actorUserId, estateId);
    const where = { estateId, ...(query.status ? { status: query.status.toUpperCase() as 'PENDING' | 'APPROVED' | 'REJECTED' } : {}) };
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.estateResidentJoinRequest.findMany({
      where, orderBy: { submittedAt: 'desc' }, skip: (query.page - 1) * query.pageSize, take: query.pageSize,
      include: { applicant: { select: { id: true, displayName: true, emailNormalized: true, phone: true } }, property: { select: { id: true, code: true } } },
      }),
      this.prisma.estateResidentJoinRequest.count({ where }),
    ]);
    return { items: rows.map((row) => ({ id: row.id, estateId, applicant: row.applicant,
      property: row.property, relationship: row.relationship?.toLowerCase() ?? null,
      note: row.note, status: row.status.toLowerCase(), submittedAt: row.submittedAt,
      reviewedAt: row.reviewedAt, decisionReason: row.decisionReason })), page: query.page, pageSize: query.pageSize, total };
  }

  async readResidentJoinRequest(actorUserId: string, requestId: string) {
    const request = await this.prisma.estateResidentJoinRequest.findFirst({
      where: { id: requestId },
      include: { estate: { select: { id: true, name: true } }, applicant: { select: { id: true, displayName: true, emailNormalized: true, phone: true } }, property: { select: { id: true, code: true } } },
    });
    if (!request) throw new NotFoundException('Resident join request not found.');
    if (request.applicantId !== actorUserId) {
      const reviewer = await this.prisma.estateMembership.findFirst({ where: {
        userId: actorUserId, estateId: request.estateId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES] }, estate: { status: 'ACTIVE' },
      }, select: { id: true } });
      if (!reviewer) throw new NotFoundException('Resident join request not found.');
    }
    return { id: request.id, estate: request.estate,
      ...(request.applicantId === actorUserId ? {} : { applicant: request.applicant }),
      property: request.property, relationship: request.relationship?.toLowerCase() ?? null,
      note: request.note, status: request.status.toLowerCase(), submittedAt: request.submittedAt,
      reviewedAt: request.reviewedAt, decisionReason: request.decisionReason };
  }

  async decideResidentJoinRequest(actorUserId: string, estateId: string, requestId: string, decision: 'approve' | 'reject', reason?: string) {
    const normalizedReason = reason?.trim() || null;
    if (decision === 'reject' && !normalizedReason) throw new BadRequestException('A reason is required to reject a resident request.');
    try {
      return await this.prisma.$transaction(async (tx) => {
        await this.requireManager(actorUserId, estateId, tx);
        const joinRequest = await tx.estateResidentJoinRequest.findFirst({ where: { id: requestId, estateId } });
        if (!joinRequest) throw new NotFoundException('Resident join request not found.');
        if (joinRequest.status !== 'PENDING') throw new ConflictException('This resident request has already been decided.');
        if (decision === 'approve' && joinRequest.propertyId) {
          const property = await tx.estateProperty.findFirst({ where: { id: joinRequest.propertyId, estateId, status: { not: 'ARCHIVED' } }, select: { id: true } });
          if (!property) throw new ConflictException('The requested property is no longer active.');
          const occupancy = await tx.propertyOccupancy.findFirst({ where: { propertyId: property.id, residentId: joinRequest.applicantId, status: 'ACTIVE' }, select: { id: true } });
          if (occupancy) throw new ConflictException('This person already has an active relationship with the property.');
        }

        const reviewedAt = new Date();
        const newStatus = decision === 'approve' ? 'APPROVED' : 'REJECTED';
        const claimed = await tx.estateResidentJoinRequest.updateMany({
          where: { id: requestId, estateId, status: 'PENDING' },
          data: { status: newStatus, reviewedById: actorUserId, reviewedAt, decisionReason: normalizedReason },
        });
        if (claimed.count !== 1) throw new ConflictException('This resident request was decided by another reviewer.');

        if (decision === 'approve') {
          const residentMembership = await tx.estateMembership.findFirst({
            where: { estateId, userId: joinRequest.applicantId, role: 'RESIDENT' },
          });
          if (residentMembership && residentMembership.status !== 'ACTIVE') {
            await tx.estateMembership.update({ where: { id: residentMembership.id }, data: { status: 'ACTIVE' } });
          } else if (!residentMembership) {
            await tx.estateMembership.create({ data: { estateId, userId: joinRequest.applicantId, role: 'RESIDENT', status: 'ACTIVE' } });
          }
          if (joinRequest.propertyId && joinRequest.relationship) {
            const now = new Date();
            const effectiveFrom = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
            await tx.propertyOccupancy.create({ data: {
              estateId, propertyId: joinRequest.propertyId, residentId: joinRequest.applicantId,
              relationship: joinRequest.relationship, effectiveFrom,
              approvedFromRequestId: joinRequest.id, createdById: actorUserId,
            } });
          }
        }
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'estate', estateId, action: `resident.join_request.${decision}d`,
          targetType: 'resident_join_request', targetId: requestId, outcome: 'success',
          reason: normalizedReason, occurredAt: reviewedAt,
        } });
        return { id: requestId, estateId, status: newStatus.toLowerCase(), reviewedAt };
      }, { isolationLevel: 'Serializable' });
    } catch (error) {
      if (this.isUniqueViolation(error)) throw new ConflictException('The resident access or property relationship already exists.');
      if (typeof error === 'object' && error !== null && 'code' in error && (error as { code?: unknown }).code === 'P2034') {
        throw new ConflictException('Another review changed this request. Reload and try again.');
      }
      throw error;
    }
  }

  private validateStructure(input: Record<string, unknown>, estateId: string, parentRows: Array<{ id: string; estateId: string; type: string; status: string }>) {
    const allowedParentTypes: Record<string, string[]> = {
      zone: [], street: ['zone'], building: ['zone', 'street'], floor: ['building'],
    };
    const policy = { allowedTypes: [...StructureNodeTypes], parentTypesByType: allowedParentTypes,
      codeRequiredByType: { zone: false, street: false, building: false, floor: false }, parentRequiredByType: { zone: false, street: false, building: false, floor: true } };
    try {
      return validateStructureNodeDraft(input, { estateId, policy, parents: parentRows.map((parent) => ({ ...parent, type: parent.type.toLowerCase() })) });
    } catch (error) {
      if (error instanceof StructureError) throw new BadRequestException({ code: error.code, message: error.message });
      throw error;
    }
  }

  private validateExistingChildren(currentType: string, _nextType: string, children: Array<{ type: string }>) {
    const childAllowed: Record<string, string[]> = { ZONE: ['STREET', 'BUILDING'], STREET: ['BUILDING'], BUILDING: ['FLOOR'], FLOOR: [] };
    if (children.some((child) => !childAllowed[currentType].includes(child.type))) {
      throw new ConflictException('The update would make an existing child structure invalid.');
    }
  }

  private structureResponse(node: { id: string; estateId: string; type: string; name: string; code: string | null; status: string; buildingType: string | null; floorCount: number | null; sortOrder: number }, parentIds: string[]) {
    return { id: node.id, estateId: node.estateId, type: node.type.toLowerCase(), name: node.name, code: node.code,
      parentIds, buildingType: node.buildingType, floorCount: node.floorCount, sortOrder: node.sortOrder,
      status: STRUCTURE_STATUSES[node.status as keyof typeof STRUCTURE_STATUSES] };
  }

  private async requireManager(
    actorUserId: string,
    estateId: string,
    tx: Prisma.TransactionClient | PrismaService = this.prisma,
  ) {
    const membership = await tx.estateMembership.findFirst({
      where: {
        userId: actorUserId,
        estateId,
        status: 'ACTIVE',
        role: { in: [...MANAGER_ROLES] },
        estate: { status: 'ACTIVE' },
      },
      select: { id: true },
    });
    if (!membership) {
      throw new ForbiddenException('Active estate property management access is required.');
    }
    return membership;
  }

  private async resolveStructureNodes(tx: Prisma.TransactionClient, estateId: string, nodeIds: string[]) {
    if (new Set(nodeIds).size !== nodeIds.length) throw new BadRequestException('A structure node can only be linked once.');
    if (!nodeIds.length) return [];
    const nodes = await tx.estateStructureNode.findMany({
      where: { estateId, id: { in: nodeIds }, status: 'ACTIVE' },
      select: { id: true, estateId: true },
    });
    if (nodes.length !== nodeIds.length) {
      throw new BadRequestException('Every linked structure node must be active and belong to this estate.');
    }
    return nodes;
  }

  private validate(input: Record<string, unknown>, parents: Array<{ id: string; estateId: string }> = []) {
    try {
      return validatePropertyDraft({
        ...input,
        status: typeof input.status === 'string' && input.status in STATUS_TO_DB
          ? input.status
          : String(input.status).toLowerCase(),
        parents,
      });
    } catch (error) {
      if (error instanceof Error) {
        throw new UnprocessableEntityException({
          code: 'INVALID_PROPERTY',
          message: error.message,
        });
      }
      throw error;
    }
  }

  private toResponse(record: {
    id: string;
    estateId: string;
    code: string;
    propertyType: string;
    status: PropertyStatus;
    unitNumber: string | null;
    address: string | null;
    description: string | null;
    latitude: { toString(): string } | null;
    longitude: { toString(): string } | null;
    archivedAt: Date | null;
    createdAt: Date;
    updatedAt: Date;
    structureLinks?: Array<{ node: { id: string; type: string; name: string; code: string | null } }>;
  }) {
    return {
      id: record.id,
      estateId: record.estateId,
      code: record.code,
      propertyType: record.propertyType,
      status: record.status.toLowerCase(),
      unitNumber: record.unitNumber,
      address: record.address,
      description: record.description,
      latitude: record.latitude?.toString() ?? null,
      longitude: record.longitude?.toString() ?? null,
      archivedAt: record.archivedAt,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      structureNodes: (record.structureLinks ?? []).map(({ node }) => ({
        id: node.id, type: node.type.toLowerCase(), name: node.name, code: node.code,
      })),
    };
  }

  private isUniqueViolation(error: unknown) {
    return typeof error === 'object' && error !== null && 'code' in error
      && (error as { code?: unknown }).code === 'P2002';
  }
}
