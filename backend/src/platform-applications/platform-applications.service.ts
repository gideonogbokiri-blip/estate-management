import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import {
  ApplicationStatus,
  ApplicationDocumentStatus,
  EstateMembershipStatus,
  EstateRole,
  EstateStatus,
} from '../generated/prisma/enums.js';
import type { Prisma } from '../generated/prisma/client.js';
import { planApplicationDecision } from '../../modules/onboarding/application-decision.js';
import { planApplicationReviewStart } from '../../modules/onboarding/application-lifecycle.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PrivateDocumentsService } from '../private-documents/private-documents.service.js';
import type { QueueQueryDto } from './platform-applications.dto.js';

const REVIEWER = 'platform_application_reviewer';
const SUPER_ADMIN = 'platform_super_admin';
const QUEUE_STATUSES = [
  ApplicationStatus.SUBMITTED,
  ApplicationStatus.UNDER_REVIEW,
  ApplicationStatus.MORE_INFORMATION_REQUIRED,
] as const;
const VISIBLE_STATUSES = [
  ...QUEUE_STATUSES,
  ApplicationStatus.APPROVED,
  ApplicationStatus.REJECTED,
] as const;
const publicApplicationSelect = {
  id: true,
  applicationCode: true,
  proposedName: true,
  estateType: true,
  address: true,
  state: true,
  lga: true,
  applicantRelationship: true,
  applicantContactName: true,
  applicantContactEmail: true,
  applicantContactPhone: true,
  managementEntityName: true,
  registrationNumber: true,
  homeCount: true,
  phaseCount: true,
  structureSummary: true,
  status: true,
  submittedAt: true,
  assignedReviewerUserId: true,
  decisionReason: true,
  decidedAt: true,
  applicant: { select: { id: true, displayName: true, emailNormalized: true } },
  _count: { select: { documents: true } },
} satisfies Prisma.EstateApplicationSelect;

@Injectable()
export class PlatformApplicationsService {
  constructor(private readonly prisma: PrismaService, private readonly privateDocuments: PrivateDocumentsService) {}

  async initialAdministrators(actorUserId: string) {
    await this.requireRole(actorUserId, SUPER_ADMIN);
    const items = await this.prisma.user.findMany({
      where: { status: 'ACTIVE' },
      orderBy: [{ displayName: 'asc' }, { emailNormalized: 'asc' }],
      take: 100,
      select: { id: true, displayName: true, emailNormalized: true },
    });
    return { items };
  }

  async queue(actorUserId: string, query: QueueQueryDto) {
    const roles = await this.requireReviewer(actorUserId);
    const status = query.status?.toUpperCase();
    const allowed: readonly string[] = VISIBLE_STATUSES;
    if (status && !allowed.includes(status as ApplicationStatus)) {
      throw new UnprocessableEntityException('Unknown application status.');
    }
    const where: Prisma.EstateApplicationWhereInput = {
      status: status ? (status as ApplicationStatus) : { in: [...QUEUE_STATUSES] },
    };
    if (!roles.includes(SUPER_ADMIN)) {
      where.OR = [
        { assignedReviewerUserId: actorUserId },
        { assignedReviewerUserId: null },
      ];
    }
    const [items, total] = await this.prisma.$transaction([
      this.prisma.estateApplication.findMany({
        where,
        orderBy: [{ submittedAt: 'asc' }, { createdAt: 'asc' }],
        skip: (query.page - 1) * query.pageSize,
        take: query.pageSize,
        select: {
          ...publicApplicationSelect,
          documents: { select: { status: true } },
        },
      }),
      this.prisma.estateApplication.count({ where }),
    ]);
    return {
      items: items.map((item) => ({
        ...item,
        status: item.status.toLowerCase(),
        documentCount: item._count.documents,
        pendingDocumentCount: item.documents.filter(
          (document) => document.status === ApplicationDocumentStatus.PENDING,
        ).length,
        documents: undefined,
        _count: undefined,
      })),
      page: query.page,
      pageSize: query.pageSize,
      total,
    };
  }

  async detail(actorUserId: string, applicationId: string) {
    const roles = await this.requireReviewer(actorUserId);
    const application = await this.prisma.estateApplication.findUnique({
      where: { id: applicationId },
      select: {
        ...publicApplicationSelect,
        documents: {
          select: {
            id: true,
            category: true,
            displayName: true,
            contentType: true,
            byteSize: true,
            status: true,
            uploadedAt: true,
            reviewedAt: true,
            reviewNote: true,
          },
          orderBy: { uploadedAt: 'asc' },
        },
      },
    });
    if (!application) throw new NotFoundException('Application not found.');
    this.assertAssignment(roles, actorUserId, application.assignedReviewerUserId);
    return {
      ...application,
      status: application.status.toLowerCase(),
      documents: application.documents.map((document) => ({
        ...document,
        byteSize: Number(document.byteSize),
        status: document.status.toLowerCase(),
      })),
      documentCount: application._count.documents,
      _count: undefined,
    };
  }

  async readApplicationDocument(actorUserId: string, applicationId: string, documentId: string) {
    const roles = await this.requireReviewer(actorUserId);
    const application = await this.prisma.estateApplication.findUnique({ where: { id: applicationId }, select: { id: true, assignedReviewerUserId: true } });
    if (!application) throw new NotFoundException('Application not found.');
    this.assertAssignment(roles, actorUserId, application.assignedReviewerUserId);
    const document = await this.prisma.estateApplicationDocument.findFirst({ where: { id: documentId, applicationId }, select: { id: true, category: true, contentType: true, objectKey: true } });
    if (!document) throw new NotFoundException('Document not found.');
    const content = await this.privateDocuments.read(document.objectKey);
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'platform', action: 'estate_application.document_accessed', targetType: 'estate_application_document', targetId: document.id,
      outcome: 'success', occurredAt: new Date(), metadata: { applicationId, category: document.category, reviewerAccess: true },
    } });
    const extension = document.contentType === 'application/pdf' ? 'pdf' : document.contentType === 'image/png' ? 'png' : 'jpg';
    return { content, contentType: document.contentType, extension };
  }

  async startReview(actorUserId: string, applicationId: string) {
    const roles = await this.requireReviewer(actorUserId);
    return this.prisma.$transaction(async (tx) => {
      const application = await tx.estateApplication.findUnique({ where: { id: applicationId } });
      if (!application) throw new NotFoundException('Application not found.');
      this.assertAssignment(roles, actorUserId, application.assignedReviewerUserId);
      let plan;
      try {
        plan = planApplicationReviewStart(
          { ...application, status: application.status.toLowerCase() },
          { actorUserId, now: new Date() },
        );
      } catch (error) {
        this.raisePlannerError(error);
      }
      const timestamp = new Date(plan!.auditEvent.occurredAt);
      const result = await tx.estateApplication.updateMany({
        where: {
          id: applicationId,
          status: ApplicationStatus.SUBMITTED,
          assignedReviewerUserId: application.assignedReviewerUserId,
        },
        data: {
          status: ApplicationStatus.UNDER_REVIEW,
          assignedReviewerUserId: actorUserId,
        },
      });
      if (result.count !== 1) throw new ConflictException('Application changed. Reload the queue and try again.');
      await this.audit(tx, actorUserId, 'estate_application.review_started', applicationId, timestamp);
      return { id: applicationId, status: 'under_review', reviewerUserId: actorUserId };
    });
  }

  async assignReviewer(actorUserId: string, applicationId: string, reviewerUserId: string) {
    await this.requireRole(actorUserId, SUPER_ADMIN);
    await this.requireRole(reviewerUserId, REVIEWER);
    return this.prisma.$transaction(async (tx) => {
      const application = await tx.estateApplication.findUnique({ where: { id: applicationId } });
      if (!application) throw new NotFoundException('Application not found.');
      if (application.status !== ApplicationStatus.SUBMITTED && application.status !== ApplicationStatus.UNDER_REVIEW) {
        throw new ConflictException('Only submitted or in-review applications can be assigned.');
      }
      const result = await tx.estateApplication.updateMany({
        where: { id: applicationId, status: application.status, assignedReviewerUserId: application.assignedReviewerUserId },
        data: { assignedReviewerUserId: reviewerUserId },
      });
      if (result.count !== 1) throw new ConflictException('Application changed. Reload and try again.');
      await this.audit(tx, actorUserId, 'estate_application.reviewer_assigned', applicationId, new Date(), {
        reviewerUserId,
      });
      return { id: applicationId, reviewerUserId, status: application.status.toLowerCase() };
    });
  }

  async decide(
    actorUserId: string,
    applicationId: string,
    decision: 'reject' | 'request_information',
    reason: string,
  ) {
    const roles = await this.requireReviewer(actorUserId);
    return this.applyDecision(actorUserId, applicationId, decision, reason, undefined, roles);
  }

  async approve(actorUserId: string, applicationId: string, initialAdministratorUserId: string) {
    const roles = await this.requireReviewer(actorUserId);
    if (!roles.includes(SUPER_ADMIN)) throw new ForbiddenException('Only a platform super administrator can approve estates.');
    return this.applyDecision(actorUserId, applicationId, 'approve', '', initialAdministratorUserId, roles);
  }

  private async applyDecision(
    actorUserId: string,
    applicationId: string,
    decision: 'approve' | 'reject' | 'request_information',
    reason: string,
    initialAdministratorUserId: string | undefined,
    roles: string[],
  ) {
    return this.prisma.$transaction(async (tx) => {
      const application = await tx.estateApplication.findUnique({ where: { id: applicationId } });
      if (!application) throw new NotFoundException('Application not found.');
      this.assertAssignment(roles, actorUserId, application.assignedReviewerUserId);
      if (decision === 'approve') {
        const administrator = await tx.user.findFirst({
          where: { id: initialAdministratorUserId, status: 'ACTIVE' },
          select: { id: true },
        });
        if (!administrator) {
          throw new UnprocessableEntityException('Select an active account as the initial estate administrator.');
        }
      } else if (!roles.includes(SUPER_ADMIN) && application.assignedReviewerUserId !== actorUserId) {
        throw new ForbiddenException('Only the assigned reviewer can decide this application.');
      }
      let plan;
      try {
        plan = planApplicationDecision(
          { ...application, status: application.status.toLowerCase() },
          { decision, actorUserId, now: new Date(), reason, initialAdministratorUserId },
        );
      } catch (error) {
        this.raisePlannerError(error);
      }
      const decidedAt = new Date(plan!.auditEvent.occurredAt);
      const update = await tx.estateApplication.updateMany({
        where: {
          id: applicationId,
          status: ApplicationStatus.UNDER_REVIEW,
          assignedReviewerUserId: application.assignedReviewerUserId,
        },
        data: {
          status: plan!.nextStatus.toUpperCase() as ApplicationStatus,
          decisionReason: decision === 'approve' ? null : reason.trim(),
          decidedByUserId: actorUserId,
          decidedAt,
          ...(decision === 'approve' ? { initialAdministratorId: initialAdministratorUserId } : {}),
        },
      });
      if (update.count !== 1) throw new ConflictException('Application changed. Reload and try again.');

      let estate: { id: string; estateCode: string } | undefined;
      if (decision === 'approve') {
        estate = await tx.estate.create({
          data: {
            estateCode: `EST-${randomBytes(6).toString('hex').toUpperCase()}`,
            approvedApplicationId: applicationId,
            name: application.proposedName,
            estateType: application.estateType,
            address: application.address,
            state: application.state,
            lga: application.lga,
            status: EstateStatus.ACTIVE,
            activatedAt: decidedAt,
            memberships: {
              create: {
                userId: initialAdministratorUserId!,
                role: EstateRole.ESTATE_ADMINISTRATOR,
                status: EstateMembershipStatus.ACTIVE,
              },
            },
          },
          select: { id: true, estateCode: true },
        });
        await this.audit(tx, actorUserId, 'estate.initial_administrator_assigned', applicationId, decidedAt, {
          estateId: estate.id,
          userId: initialAdministratorUserId,
        });
      }
      await this.audit(tx, actorUserId, `estate_application.${decision}`, applicationId, decidedAt, {
        ...(decision === 'approve' ? { estateId: estate!.id } : {}),
        ...(decision === 'approve' ? {} : { reason: reason.trim() }),
      });
      return {
        id: applicationId,
        status: plan!.nextStatus,
        ...(estate ? { estate } : {}),
      };
    });
  }

  private async requireReviewer(actorUserId: string): Promise<string[]> {
    const grants = await this.prisma.platformRoleGrant.findMany({
      where: { userId: actorUserId, roleKey: { in: [REVIEWER, SUPER_ADMIN] } },
      select: { roleKey: true },
    });
    const roles = grants.map((grant) => grant.roleKey);
    if (!roles.length) throw new ForbiddenException('Platform application reviewer permission is required.');
    return roles;
  }

  private async requireRole(userId: string, roleKey: string): Promise<void> {
    const grant = await this.prisma.platformRoleGrant.findUnique({
      where: { userId_roleKey: { userId, roleKey } },
      select: { id: true },
    });
    if (!grant) throw new ForbiddenException('Required platform permission is missing.');
  }

  private assertAssignment(roles: string[], actorUserId: string, assignedReviewerUserId: string | null) {
    if (assignedReviewerUserId && assignedReviewerUserId !== actorUserId && !roles.includes(SUPER_ADMIN)) {
      throw new ForbiddenException('This application is assigned to another reviewer.');
    }
  }

  private async audit(
    tx: Prisma.TransactionClient,
    actorUserId: string,
    action: string,
    targetId: string,
    occurredAt: Date,
    metadata?: Prisma.InputJsonObject,
  ) {
    await tx.auditEvent.create({
      data: {
        actorUserId,
        scope: 'platform',
        action,
        targetType: 'estate_application',
        targetId,
        outcome: 'success',
        occurredAt,
        ...(metadata ? { metadata } : {}),
      },
    });
  }

  private raisePlannerError(error: unknown): never {
    if (error instanceof Error && 'code' in error) {
      throw new UnprocessableEntityException({
        code: String((error as Error & { code: unknown }).code),
        message: error.message,
      });
    }
    throw error;
  }
}
