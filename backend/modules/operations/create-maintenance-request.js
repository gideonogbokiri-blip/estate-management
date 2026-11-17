const { createHash, createHmac } = require('node:crypto');
const { MaintenanceStatus } = require('./maintenance');

class MaintenanceRequestCreationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MaintenanceRequestCreationError';
    this.code = code;
  }
}

const CATEGORIES = Object.freeze(['plumbing', 'electrical', 'security', 'cleaning', 'other']);
const PRIORITIES = Object.freeze(['normal', 'high', 'urgent']);

/** Create a resident maintenance request within the actor's active estate/property relationship. */
function createMaintenanceRequestUseCase({
  transaction,
  resolveResidentPropertyAccess,
  findPropertyForUpdate,
  getMaintenancePolicy,
  verifyAttachments,
  generateRequestId,
  createRequestRecord,
  appendAuditEvent,
  enqueueRequestNotice,
  readMaintenanceCreationIdempotency,
  claimMaintenanceCreationIdempotency,
  completeMaintenanceCreationIdempotency,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction, resolveResidentPropertyAccess, findPropertyForUpdate,
    getMaintenancePolicy, verifyAttachments, generateRequestId,
    createRequestRecord, appendAuditEvent, enqueueRequestNotice,
    readMaintenanceCreationIdempotency, claimMaintenanceCreationIdempotency,
    completeMaintenanceCreationIdempotency,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) {
    throw new MaintenanceRequestCreationError('MISSING_ADAPTER', `Maintenance request adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new MaintenanceRequestCreationError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function createMaintenanceRequest({
    actorUserId, estateId, propertyId, category, priority, description, attachmentIds = [], idempotencyKey,
  } = {}) {
    if (!actorUserId || !estateId) {
      throw new MaintenanceRequestCreationError('INVALID_CREATION_INPUT', 'Authenticated resident and estate context are required.');
    }
    const normalizedCategory = typeof category === 'string' ? category.trim().toLowerCase() : '';
    const normalizedPriority = typeof priority === 'string' ? priority.trim().toLowerCase() : '';
    const normalizedDescription = typeof description === 'string' ? description.trim() : '';
    if (!CATEGORIES.includes(normalizedCategory) || !PRIORITIES.includes(normalizedPriority)) {
      throw new MaintenanceRequestCreationError('INVALID_CLASSIFICATION', 'Choose a supported maintenance category and priority.');
    }
    if (!normalizedDescription || normalizedDescription.length > 700) {
      throw new MaintenanceRequestCreationError('INVALID_DESCRIPTION', 'Describe the issue in no more than 700 characters.');
    }
    if (typeof idempotencyKey !== 'string' || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new MaintenanceRequestCreationError('INVALID_IDEMPOTENCY_KEY', 'A valid request key is required to submit maintenance safely.');
    }
    if (!Array.isArray(attachmentIds) || attachmentIds.length > 5
      || new Set(attachmentIds).size !== attachmentIds.length
      || attachmentIds.some((id) => typeof id !== 'string' || !id.trim())) {
      throw new MaintenanceRequestCreationError('INVALID_ATTACHMENTS', 'Provide up to five unique private attachment references.');
    }

    return transaction(async (tx) => {
      const access = await resolveResidentPropertyAccess(tx, { actorUserId, estateId, propertyId: propertyId ?? null });
      const authorizedPropertyId = propertyId ?? access?.propertyId;
      if (!access || access.estateId !== estateId || !authorizedPropertyId
        || String(access.propertyId) !== String(authorizedPropertyId)
        || access.userId !== actorUserId || access.active !== true || access.maySubmitMaintenance !== true) {
        throw new MaintenanceRequestCreationError('RESIDENT_ACCESS_DENIED', 'The resident has no active maintenance access for this property.');
      }

      const property = await findPropertyForUpdate(tx, { estateId, propertyId: authorizedPropertyId });
      if (!property || property.estateId !== estateId || String(property.id) !== String(authorizedPropertyId)
        || property.status === 'archived') {
        throw new MaintenanceRequestCreationError('PROPERTY_NOT_FOUND', 'The property was not found in this estate.');
      }
      const policy = await getMaintenancePolicy(tx, { estateId, property, access });
      if (!policy || !Array.isArray(policy.allowedCategories) || !Array.isArray(policy.allowedPriorities)
        || !policy.allowedCategories.includes(normalizedCategory)
        || !policy.allowedPriorities.includes(normalizedPriority)) {
        throw new MaintenanceRequestCreationError('CLASSIFICATION_NOT_ALLOWED', 'This category or priority is not enabled for this property.');
      }
      const attachmentsValid = await verifyAttachments(tx, {
        actorUserId, estateId, propertyId: authorizedPropertyId, attachmentIds,
      });
      if (attachmentsValid !== true) {
        throw new MaintenanceRequestCreationError('INVALID_ATTACHMENTS', 'Every attachment must be a private file authorized for this resident request.');
      }

      const idempotencyKeyHash = createHash('sha256')
        .update(`maintenance-create:v1:${idempotencyKey}`, 'utf8').digest('hex');
      const payloadHash = createHmac('sha256', idempotencyKey)
        .update(JSON.stringify([String(authorizedPropertyId), normalizedCategory, normalizedPriority,
          normalizedDescription, [...attachmentIds].sort()]), 'utf8').digest('hex');
      const scope = { actorUserId, estateId, idempotencyKeyHash };
      const replay = (record) => {
        if (!record || String(record.actorUserId) !== String(actorUserId) || String(record.estateId) !== String(estateId)
          || record.idempotencyKeyHash !== idempotencyKeyHash || record.payloadHash !== payloadHash
          || record.state !== 'completed' || !record.result || String(record.result.estateId) !== String(estateId)
          || !record.result.requestId || String(record.result.propertyId) !== String(authorizedPropertyId)
          || record.result.category !== normalizedCategory || record.result.priority !== normalizedPriority
          || record.result.description !== normalizedDescription || record.result.status !== MaintenanceStatus.SUBMITTED
          || typeof record.result.submittedAt !== 'string' || Number.isNaN(Date.parse(record.result.submittedAt))
          || new Date(record.result.submittedAt).toISOString() !== record.result.submittedAt) {
          throw new MaintenanceRequestCreationError('IDEMPOTENCY_KEY_REUSED', 'This request key is already in use with different or incomplete maintenance details.');
        }
        return Object.freeze({
          requestId: record.result.requestId, estateId, propertyId: authorizedPropertyId,
          category: normalizedCategory, priority: normalizedPriority, description: normalizedDescription,
          status: MaintenanceStatus.SUBMITTED, submittedAt: record.result.submittedAt, replayed: true,
        });
      };
      const prior = await readMaintenanceCreationIdempotency(tx, scope);
      if (prior) return replay(prior);
      const claim = await claimMaintenanceCreationIdempotency(tx, { ...scope, payloadHash });
      if (claim?.state === 'completed') return replay(claim.record);
      if (!claim || claim.state !== 'claimed' || !claim.id
        || String(claim.actorUserId) !== String(actorUserId) || String(claim.estateId) !== String(estateId)
        || claim.idempotencyKeyHash !== idempotencyKeyHash || claim.payloadHash !== payloadHash) {
        throw new MaintenanceRequestCreationError('IDEMPOTENCY_CLAIM_FAILED', 'The maintenance request could not be claimed safely.');
      }

      const id = await generateRequestId(tx, { estateId });
      if (!id) throw new MaintenanceRequestCreationError('INVALID_REQUEST_ID', 'A maintenance request reference could not be generated.');
      const submittedAt = new Date(clock()).toISOString();
      const request = Object.freeze({
        id, estateId, propertyId: authorizedPropertyId, requesterUserId: actorUserId,
        category: normalizedCategory, priority: normalizedPriority,
        description: normalizedDescription, attachmentIds: Object.freeze([...attachmentIds]),
        status: MaintenanceStatus.SUBMITTED, submittedAt, createdAt: submittedAt,
      });
      const created = await createRequestRecord(tx, request);
      if (!created || String(created.id) !== String(id) || created.estateId !== estateId
        || String(created.propertyId) !== String(authorizedPropertyId) || created.requesterUserId !== actorUserId
        || created.status !== MaintenanceStatus.SUBMITTED) {
        throw new MaintenanceRequestCreationError('INVALID_CREATE_RESULT', 'The repository did not persist the planned request in the selected estate.');
      }
      await appendAuditEvent(tx, {
        actorUserId, scope: 'estate', estateId, action: 'maintenance.submit',
        targetType: 'maintenance_request', targetId: id, outcome: 'success', occurredAt: submittedAt,
      });
      // The adapter writes a retryable notice to the existing outbox in this transaction.
      await enqueueRequestNotice(tx, { estateId, requestId: id, propertyId: authorizedPropertyId, requesterUserId: actorUserId });
      const result = Object.freeze({ requestId: id, estateId, propertyId: authorizedPropertyId, category: normalizedCategory,
        priority: normalizedPriority, description: normalizedDescription,
        status: MaintenanceStatus.SUBMITTED, submittedAt });
      const completed = await completeMaintenanceCreationIdempotency(tx, { claim, payloadHash, result });
      if (!completed || String(completed.id) !== String(claim.id) || completed.state !== 'completed'
        || String(completed.actorUserId) !== String(actorUserId) || String(completed.estateId) !== String(estateId)
        || completed.idempotencyKeyHash !== idempotencyKeyHash || completed.payloadHash !== payloadHash
        || String(completed.result?.requestId) !== String(id)) {
        throw new MaintenanceRequestCreationError('IDEMPOTENCY_COMPLETION_FAILED', 'The maintenance request could not be committed for safe retry.');
      }
      return result;
    });
  };
}

module.exports = { MaintenanceRequestCreationError, createMaintenanceRequestUseCase };
