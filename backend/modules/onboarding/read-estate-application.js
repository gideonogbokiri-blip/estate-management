class EstateApplicationReadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationReadError';
    this.code = code;
  }
}

function safeText(value, field, max = 500) {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string' || value.length > max) {
    throw new EstateApplicationReadError('INVALID_PROJECTION', `The application ${field} field is invalid.`);
  }
  return value;
}

function safeTimestamp(value, field) {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string' || Number.isNaN(new Date(value).getTime())) {
    throw new EstateApplicationReadError('INVALID_PROJECTION', `The application ${field} timestamp is invalid.`);
  }
  return new Date(value).toISOString();
}

function sanitizeEstateApplicationDetail(application, projection, documents) {
  if (!application?.id || !projection || typeof projection !== 'object' || Array.isArray(projection)) {
    throw new EstateApplicationReadError('INVALID_PROJECTION', 'An authorized application projection is required.');
  }
  const allowed = new Set([
    'applicationCode', 'proposedName', 'estateType', 'address', 'state', 'lga', 'managementEntityName',
    'applicantUserId', 'applicantDisplayName', 'applicantEmail', 'applicantPhone', 'applicantRelationship',
    'registrationNumber', 'homeCount', 'phaseCount', 'structureSummary', 'mapPinProvided', 'status',
    'submittedAt', 'assignedReviewerDisplayName',
  ]);
  if (Object.keys(projection).some((key) => !allowed.has(key))) {
    throw new EstateApplicationReadError('UNSAFE_PROJECTION', 'The application detail projection contains unapproved fields.');
  }
  const {
    applicationCode = null,
    proposedName,
    estateType = null,
    address = null,
    state = null,
    lga = null,
    managementEntityName = null,
    registrationNumber = null,
    homeCount = null,
    phaseCount = null,
    applicantUserId,
    applicantDisplayName,
    applicantEmail = null,
    applicantPhone = null,
    applicantRelationship = null,
    structureSummary = null,
    mapPinProvided = false,
    status,
    submittedAt,
    assignedReviewerDisplayName = null,
  } = projection;
  if (!['string', 'number'].includes(typeof applicantUserId)
    || String(applicantUserId) !== String(application.applicantUserId)
    || typeof status !== 'string' || status !== application.status
    || (applicationCode !== null && (typeof applicationCode !== 'string' || applicationCode.length > 80))
    || typeof proposedName !== 'string' || proposedName.length > 200
    || typeof applicantDisplayName !== 'string' || applicantDisplayName.length > 200
    || (applicantEmail !== null && (typeof applicantEmail !== 'string' || applicantEmail.length > 254))
    || (applicantPhone !== null && (typeof applicantPhone !== 'string' || applicantPhone.length > 50))
    || typeof mapPinProvided !== 'boolean'
    || (homeCount !== null && (!Number.isSafeInteger(homeCount) || homeCount < 1))
    || (phaseCount !== null && (!Number.isSafeInteger(phaseCount) || phaseCount < 0))
    || (structureSummary !== null && (typeof structureSummary !== 'string' || structureSummary.length > 500))) {
    throw new EstateApplicationReadError('INVALID_PROJECTION', 'The application detail projection does not match the authorized record.');
  }
  if (application.submittedAt && safeTimestamp(submittedAt, 'submission') !== safeTimestamp(application.submittedAt, 'submission')) {
    throw new EstateApplicationReadError('PROJECTION_RECORD_MISMATCH', 'The projected submission time does not match the authorized application.');
  }
  if (!Array.isArray(documents)) throw new EstateApplicationReadError('INVALID_DOCUMENT_RESULT', 'Document metadata must be a list.');
  const seenDocumentIds = new Set();
  const safeDocuments = documents.map((document) => {
    if (typeof document?.accessId !== 'string' || !document.accessId || document.accessId.length > 200 || seenDocumentIds.has(document.accessId)) {
      throw new EstateApplicationReadError('INVALID_DOCUMENT_RESULT', 'Document metadata contains a missing or duplicate document.');
    }
    seenDocumentIds.add(document.accessId);
    const reviewStatus = safeText(document.reviewStatus, 'document review status', 40);
    if (!['pending', 'verified', 'rejected', 'more_information_required'].includes(reviewStatus)) {
      throw new EstateApplicationReadError('INVALID_DOCUMENT_RESULT', 'Document metadata contains an unsupported review status.');
    }
    return Object.freeze({
      accessId: document.accessId,
      category: safeText(document.category, 'document category', 80),
      label: safeText(document.label, 'document label', 160),
      uploadedAt: safeTimestamp(document.uploadedAt, 'document upload'),
      reviewStatus,
    });
  });
  return Object.freeze({
    id: application.id,
    applicationCode,
    proposedName,
    estateType: safeText(estateType, 'estate type', 80),
    location: Object.freeze({
      address: safeText(address, 'address', 300),
      state: safeText(state, 'state', 100),
      lga: safeText(lga, 'LGA', 100),
    }),
    managementEntityName: safeText(managementEntityName, 'management entity', 200),
    registrationNumber: safeText(registrationNumber, 'management registration number', 100),
    applicant: Object.freeze({
      userId: applicantUserId,
      displayName: applicantDisplayName,
      email: safeText(applicantEmail, 'applicant email', 254),
      phone: safeText(applicantPhone, 'applicant phone', 50),
      relationship: safeText(applicantRelationship, 'applicant relationship', 100),
    }),
    structureSummary,
    homeCount,
    phaseCount,
    mapPinProvided,
    status,
    submittedAt: safeTimestamp(submittedAt, 'submission'),
    assignedReviewerDisplayName: safeText(assignedReviewerDisplayName, 'reviewer name', 200),
    documents: Object.freeze(safeDocuments),
  });
}

/** Read an application only through an actor-scoped repository and safe projection. */
function createEstateApplicationDetailUseCase({
  transaction,
  findApplicationForAuthorizedReader,
  projectEstateApplicationDetailForActor,
  listAuthorizedApplicationDocumentMetadata,
} = {}) {
  const ports = { transaction, findApplicationForAuthorizedReader, projectEstateApplicationDetailForActor, listAuthorizedApplicationDocumentMetadata };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new EstateApplicationReadError('MISSING_ADAPTER', `Application detail adapters are required: ${missing.join(', ')}.`);

  return async function readEstateApplication({ actorUserId, applicationId } = {}) {
    if (!actorUserId || !applicationId) throw new EstateApplicationReadError('INVALID_INPUT', 'Authenticated actor and application are required.');
    return transaction(async (tx) => {
      // This adapter applies applicant or assigned-reviewer/platform scope before returning a record.
      const result = await findApplicationForAuthorizedReader(tx, { actorUserId, applicationId });
      if (!result?.application || !['applicant', 'assigned_reviewer', 'platform_reviewer'].includes(result.accessScope)) {
        throw new EstateApplicationReadError('APPLICATION_NOT_FOUND', 'The application was not found for this account.');
      }
      if (String(result.application.id) !== String(applicationId)) {
        throw new EstateApplicationReadError('INVALID_REPOSITORY_RESULT', 'The repository returned a different application.');
      }
      const projection = await projectEstateApplicationDetailForActor({
        actorUserId,
        accessScope: result.accessScope,
        application: result.application,
        tx,
      });
      const documents = await listAuthorizedApplicationDocumentMetadata({
        actorUserId,
        accessScope: result.accessScope,
        application: result.application,
        tx,
      });
      return sanitizeEstateApplicationDetail(result.application, projection, documents);
    });
  };
}

module.exports = { EstateApplicationReadError, createEstateApplicationDetailUseCase, sanitizeEstateApplicationDetail };
