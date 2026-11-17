import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import {
  planApplicationDraftUpdate,
  planApplicationSubmission,
} from '../../modules/onboarding/application-lifecycle.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { UpdateApplicationDraftDto } from './applications.dto.js';
import type { UploadApplicationDocumentDto } from './applications.dto.js';
import type { Prisma } from '../generated/prisma/client.js';
import { PrivateDocumentsService } from '../private-documents/private-documents.service.js';

const publicDraftFields = [
  'proposedName',
  'estateType',
  'address',
  'state',
  'lga',
  'latitude',
  'longitude',
  'applicantRelationship',
  'applicantContactName',
  'applicantContactEmail',
  'applicantContactPhone',
  'managementEntityName',
  'registrationNumber',
  'homeCount',
  'phaseCount',
  'structureSummary',
] as const;

type DraftChanges = Record<string, string | number | null>;

@Injectable()
export class ApplicationsService {
  constructor(private readonly prisma: PrismaService, private readonly privateDocuments: PrivateDocumentsService) {}

  async createDraft(actorUserId: string) {
    return this.prisma.$transaction(async (tx) => {
      const timestamp = new Date();
      const application = await tx.estateApplication.create({
        data: {
          applicationCode: `EA-${randomBytes(8).toString('hex').toUpperCase()}`,
          applicantUserId: actorUserId,
        },
        select: { id: true, applicationCode: true, status: true, createdAt: true },
      });

      await tx.auditEvent.create({
        data: {
          actorUserId,
          scope: 'platform',
          action: 'estate_application.draft_created',
          targetType: 'estate_application',
          targetId: application.id,
          outcome: 'success',
          occurredAt: timestamp,
        },
      });

      return {
        id: application.id,
        code: application.applicationCode,
        status: application.status.toLowerCase(),
        createdAt: application.createdAt,
      };
    });
  }

  async listMine(actorUserId: string) {
    const applications = await this.prisma.estateApplication.findMany({
      where: { applicantUserId: actorUserId },
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: {
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
        updatedAt: true,
        decisionReason: true,
        documents: { select: { id: true, category: true, displayName: true, contentType: true, byteSize: true, status: true, uploadedAt: true }, orderBy: { uploadedAt: 'asc' } },
      },
    });
    return {
      items: applications.map((application) => ({
        ...application,
        documents: application.documents.map((document) => ({ ...document, byteSize: Number(document.byteSize), status: document.status.toLowerCase() })),
        status: application.status.toLowerCase(),
      })),
      total: applications.length,
    };
  }

  async uploadDocument(actorUserId: string, applicationId: string, input: UploadApplicationDocumentDto, file: Express.Multer.File, idempotencyKey: string | undefined) {
    if (!idempotencyKey || idempotencyKey.length < 8 || idempotencyKey.length > 128) throw new BadRequestException('A valid Idempotency-Key header is required.');
    if (!file?.buffer?.length) throw new BadRequestException('Choose a non-empty PDF, JPEG or PNG document.');
    const detected = this.detectDocumentType(file.buffer);
    const category = input.category;
    const displayName = this.safeDisplayName(file.originalname, detected.extension);
    const checksum = createHash('sha256').update(file.buffer).digest('hex');
    const keyHash = this.hash(`application-document:v1:${idempotencyKey}`);
    const payloadHash = this.hash(JSON.stringify({ category, displayName, contentType: detected.contentType, checksum, byteSize: file.buffer.length }));
    const where = { applicationId_idempotencyKeyHash: { applicationId, idempotencyKeyHash: keyHash } };
    const existing = await this.prisma.estateApplicationDocument.findUnique({ where });
    if (existing) {
      if (existing.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was already used for different document content.');
      await this.assertApplicantOwnsApplication(actorUserId, applicationId);
      return this.documentView(existing, true);
    }
    await this.assertApplicantCanManageDraft(actorUserId, applicationId);
    const documentId = randomUUID();
    const objectKey = await this.privateDocuments.storeApplicationDocument(applicationId, documentId, detected.extension, file.buffer);
    try {
      const result = await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM estate_applications WHERE id = ${applicationId}::uuid AND applicant_user_id = ${actorUserId}::uuid FOR UPDATE`;
        const application = await tx.estateApplication.findFirst({ where: { id: applicationId, applicantUserId: actorUserId }, select: { id: true, status: true } });
        if (!application) throw new NotFoundException('Application not found.');
        if (!['DRAFT', 'MORE_INFORMATION_REQUIRED'].includes(application.status)) throw new ConflictException('Documents can only be added to draft or returned applications.');
        const prior = await tx.estateApplicationDocument.findUnique({ where });
        if (prior) {
          if (prior.payloadHash !== payloadHash) throw new ConflictException('This idempotency key was already used for different document content.');
          return { document: prior, stored: false };
        }
        const uploadedAt = new Date();
        const document = await tx.estateApplicationDocument.create({ data: {
          id: documentId, applicationId, category, displayName, objectKey, contentType: detected.contentType,
          byteSize: BigInt(file.buffer.length), checksum, idempotencyKeyHash: keyHash, payloadHash, uploadedAt,
        } });
        await tx.auditEvent.create({ data: {
          actorUserId, scope: 'platform', action: 'estate_application.document_uploaded', targetType: 'estate_application_document', targetId: document.id,
          outcome: 'success', occurredAt: uploadedAt, metadata: { applicationId, category, contentType: detected.contentType, byteSize: file.buffer.length },
        } });
        return { document, stored: true };
      });
      if (!result.stored) await this.privateDocuments.remove(objectKey);
      return this.documentView(result.document, !result.stored);
    } catch (error) {
      await this.privateDocuments.remove(objectKey);
      if ((error as { code?: string }).code === 'P2002') {
        const prior = await this.prisma.estateApplicationDocument.findUnique({ where });
        if (prior && prior.payloadHash === payloadHash) return this.documentView(prior, true);
      }
      throw error;
    }
  }

  async listApplicantDocuments(actorUserId: string, applicationId: string) {
    const application = await this.prisma.estateApplication.findFirst({
      where: { id: applicationId, applicantUserId: actorUserId },
      select: { id: true },
    });
    if (!application) throw new NotFoundException('Application not found.');
    const documents = await this.prisma.estateApplicationDocument.findMany({
      where: { applicationId },
      orderBy: { uploadedAt: 'asc' },
      select: { id: true, category: true, displayName: true, contentType: true, byteSize: true, status: true, uploadedAt: true },
    });
    return { items: documents.map((document) => ({ ...document, byteSize: Number(document.byteSize), status: document.status.toLowerCase() })) };
  }

  async readApplicantDocument(actorUserId: string, applicationId: string, documentId: string) {
    const document = await this.prisma.estateApplicationDocument.findFirst({ where: { id: documentId, applicationId, application: { applicantUserId: actorUserId } } });
    if (!document) throw new NotFoundException('Document not found.');
    const content = await this.privateDocuments.read(document.objectKey);
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'platform', action: 'estate_application.document_accessed', targetType: 'estate_application_document', targetId: document.id,
      outcome: 'success', occurredAt: new Date(), metadata: { applicationId, category: document.category },
    } });
    return { content, contentType: document.contentType, extension: this.extensionFor(document.contentType) };
  }

  private async assertApplicantCanManageDraft(actorUserId: string, applicationId: string) {
    const application = await this.prisma.estateApplication.findFirst({ where: { id: applicationId, applicantUserId: actorUserId }, select: { id: true, status: true } });
    if (!application) throw new NotFoundException('Application not found.');
    if (!['DRAFT', 'MORE_INFORMATION_REQUIRED'].includes(application.status)) throw new ConflictException('Documents can only be added to draft or returned applications.');
  }

  private async assertApplicantOwnsApplication(actorUserId: string, applicationId: string) {
    const application = await this.prisma.estateApplication.findFirst({ where: { id: applicationId, applicantUserId: actorUserId }, select: { id: true } });
    if (!application) throw new NotFoundException('Application not found.');
  }

  private documentView(document: { id: string; applicationId: string; category: string; displayName: string; contentType: string; byteSize: bigint; status: string; uploadedAt: Date }, replayed: boolean) {
    return { id: document.id, applicationId: document.applicationId, category: document.category, displayName: document.displayName, contentType: document.contentType, byteSize: Number(document.byteSize), status: document.status.toLowerCase(), uploadedAt: document.uploadedAt.toISOString(), replayed };
  }

  private detectDocumentType(bytes: Buffer): { contentType: string; extension: 'pdf' | 'jpg' | 'png' } {
    if (bytes.length > 10 * 1024 * 1024) throw new BadRequestException('Documents must be 10 MB or smaller.');
    if (bytes.subarray(0, 5).toString('ascii') === '%PDF-') return { contentType: 'application/pdf', extension: 'pdf' };
    if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return { contentType: 'image/png', extension: 'png' };
    if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return { contentType: 'image/jpeg', extension: 'jpg' };
    throw new BadRequestException('The file content must be a valid PDF, JPEG or PNG.');
  }

  private safeDisplayName(value: string, extension: string) {
    const base = value.replace(/\\/g, '/').split('/').pop()?.replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, 160);
    return base || `supporting-document.${extension}`;
  }

  private extensionFor(contentType: string) { return contentType === 'application/pdf' ? 'pdf' : contentType === 'image/png' ? 'png' : 'jpg'; }
  private hash(value: string) { return createHash('sha256').update(value, 'utf8').digest('hex'); }

  async updateDraft(
    actorUserId: string,
    applicationId: string,
    dto: UpdateApplicationDraftDto,
  ) {
    const changes = this.pickChanges(dto);
    if (Object.keys(changes).length === 0) {
      throw new UnprocessableEntityException({
        code: 'EMPTY_CHANGES',
        message: 'Provide at least one application field to update.',
      });
    }

    return this.prisma.$transaction(async (tx) => {
      const record = await tx.estateApplication.findFirst({
        where: { id: applicationId, applicantUserId: actorUserId },
      });
      if (!record) throw new NotFoundException('Application not found.');

      let plan;
      try {
        plan = planApplicationDraftUpdate(
          {
            ...record,
            id: record.id,
            applicantUserId: record.applicantUserId,
            status: record.status.toLowerCase(),
            latitude: record.latitude === null ? null : Number(record.latitude),
            longitude: record.longitude === null ? null : Number(record.longitude),
            homeCount: record.homeCount,
            phaseCount: record.phaseCount,
          },
          { actorUserId, now: new Date(), changes },
        );
      } catch (error) {
        if (error instanceof Error && 'code' in error) {
          throw new UnprocessableEntityException({
            code: String((error as Error & { code: unknown }).code),
            message: error.message,
          });
        }
        throw error;
      }

      const updated = await tx.estateApplication.updateMany({
        where: {
          id: applicationId,
          applicantUserId: actorUserId,
          status: record.status,
        },
        data: this.toPersistenceChanges(plan.changes),
      });
      if (updated.count !== 1) {
        throw new UnprocessableEntityException({
          code: 'CONCURRENT_APPLICATION_UPDATE',
          message: 'The application changed while it was being edited. Reload and try again.',
        });
      }
      await this.appendAudit(tx, plan.auditEvent);
      const saved = await tx.estateApplication.findUniqueOrThrow({
        where: { id: applicationId },
        select: { id: true, applicationCode: true, status: true, updatedAt: true },
      });
      return {
        id: saved.id,
        code: saved.applicationCode,
        status: saved.status.toLowerCase(),
        updatedAt: saved.updatedAt,
      };
    });
  }

  async submit(actorUserId: string, applicationId: string) {
    return this.prisma.$transaction(async (tx) => {
      const record = await tx.estateApplication.findFirst({
        where: { id: applicationId, applicantUserId: actorUserId },
      });
      if (!record) throw new NotFoundException('Application not found.');

      let plan;
      try {
        plan = planApplicationSubmission(
          {
            ...record,
            status: record.status.toLowerCase(),
            latitude: record.latitude === null ? null : Number(record.latitude),
            longitude: record.longitude === null ? null : Number(record.longitude),
          },
          {
            actorUserId,
            now: new Date(),
            requiredFields: [
              'proposedName', 'estateType', 'address', 'state', 'lga',
              'applicantRelationship', 'applicantContactName',
              'applicantContactEmail', 'applicantContactPhone',
              'managementEntityName', 'homeCount',
            ],
            // Document requirements are intentionally empty until this product defines its policy.
            requiredDocumentCategories: [],
            verifiedDocumentCategories: [],
          },
        );
      } catch (error) {
        if (error instanceof Error && 'code' in error) {
          throw new UnprocessableEntityException({
            code: String((error as Error & { code: unknown }).code),
            message: error.message,
          });
        }
        throw error;
      }

      const submittedAt = new Date(plan.effects[0].submittedAt);
      const updated = await tx.estateApplication.updateMany({
        where: {
          id: applicationId,
          applicantUserId: actorUserId,
          status: record.status,
        },
        data: { status: 'SUBMITTED', submittedAt },
      });
      if (updated.count !== 1) {
        throw new UnprocessableEntityException({
          code: 'CONCURRENT_APPLICATION_UPDATE',
          message: 'The application changed while it was being submitted. Reload and try again.',
        });
      }
      await this.appendAudit(tx, plan.auditEvent);
      return {
        id: record.id,
        applicationCode: record.applicationCode,
        status: 'submitted',
        submittedAt,
      };
    });
  }

  private pickChanges(dto: UpdateApplicationDraftDto): DraftChanges {
    const changes: DraftChanges = {};
    for (const field of publicDraftFields) {
      const value = dto[field];
      if (value !== undefined) changes[field] = value;
    }
    return changes;
  }

  private toPersistenceChanges(changes: DraftChanges): Prisma.EstateApplicationUpdateInput {
    const data: Prisma.EstateApplicationUpdateInput = {};
    for (const [field, value] of Object.entries(changes)) {
      switch (field) {
        case 'proposedName': data.proposedName = value as string; break;
        case 'estateType': data.estateType = value as string; break;
        case 'address': data.address = value as string; break;
        case 'state': data.state = value as string; break;
        case 'lga': data.lga = value as string; break;
        case 'latitude': data.latitude = value === null ? null : Number(value); break;
        case 'longitude': data.longitude = value === null ? null : Number(value); break;
        case 'applicantRelationship': data.applicantRelationship = value as string; break;
        case 'applicantContactName': data.applicantContactName = value as string; break;
        case 'applicantContactEmail': data.applicantContactEmail = value as string; break;
        case 'applicantContactPhone': data.applicantContactPhone = value as string; break;
        case 'managementEntityName': data.managementEntityName = value as string; break;
        case 'registrationNumber': data.registrationNumber = value as string | null; break;
        case 'homeCount': data.homeCount = Number(value); break;
        case 'phaseCount': data.phaseCount = value === null ? null : Number(value); break;
        case 'structureSummary': data.structureSummary = value as string | null; break;
      }
    }
    return data;
  }

  private async appendAudit(
    tx: Prisma.TransactionClient,
    event: {
      actorUserId: string;
      scope: string;
      action: string;
      targetType: string;
      targetId: string;
      outcome: string;
      occurredAt: string;
    },
  ) {
    await tx.auditEvent.create({
      data: {
        ...event,
        occurredAt: new Date(event.occurredAt),
      },
    });
  }
}
