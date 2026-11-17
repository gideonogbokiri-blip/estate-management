const { ApplicationStatus } = require('./application-decision');

const QueueStatuses = Object.freeze([
  ApplicationStatus.SUBMITTED,
  ApplicationStatus.UNDER_REVIEW,
  ApplicationStatus.MORE_INFORMATION_REQUIRED,
  ApplicationStatus.APPROVED,
  ApplicationStatus.REJECTED,
]);

class EstateApplicationQueueError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationQueueError';
    this.code = code;
  }
}

function normalizeApplicationQueueQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    throw new EstateApplicationQueueError('INVALID_QUERY', 'Application queue filters must be an object.');
  }
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 50) {
    throw new EstateApplicationQueueError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 50.');
  }
  const status = query.status || 'open';
  if (status !== 'all' && status !== 'open' && !QueueStatuses.includes(status)) {
    throw new EstateApplicationQueueError('INVALID_STATUS_FILTER', 'Choose a supported application status.');
  }
  const search = typeof query.search === 'string' ? query.search.trim() : '';
  if (query.search !== undefined && typeof query.search !== 'string') {
    throw new EstateApplicationQueueError('INVALID_SEARCH', 'Search must be text.');
  }
  if (search.length > 100) throw new EstateApplicationQueueError('INVALID_SEARCH', 'Search text must be 100 characters or fewer.');
  const filters = {};
  if (status === 'open') filters.statuses = Object.freeze([ApplicationStatus.SUBMITTED, ApplicationStatus.UNDER_REVIEW]);
  else if (status !== 'all') filters.status = status;
  if (search) filters.search = search;
  return Object.freeze({ page, pageSize, filters: Object.freeze(filters), sort: 'submittedAt_desc' });
}

function validTimestamp(value, required = false) {
  if ((!required && (value === null || value === undefined)) || typeof value === 'string') {
    return !required && (value === null || value === undefined) || !Number.isNaN(new Date(value).getTime());
  }
  return false;
}

function sanitizeApplicationProjection(record, projection) {
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)) {
    throw new EstateApplicationQueueError('PROJECTION_REQUIRED', 'Every application requires an actor-authorized queue projection.');
  }
  const allowed = new Set(['applicationCode', 'proposedName', 'estateType', 'state', 'lga', 'applicantUserId', 'applicantDisplayName', 'submittedAt', 'assignedReviewerUserId', 'assignedReviewerDisplayName', 'documentCount', 'pendingDocumentReviewCount']);
  if (Object.keys(projection).some((key) => !allowed.has(key))) {
    throw new EstateApplicationQueueError('UNSAFE_PROJECTION', 'The queue projection contains fields outside the application summary contract.');
  }
  const {
    applicationCode = null,
    proposedName,
    estateType = null,
    state = null,
    lga = null,
    applicantUserId,
    applicantDisplayName,
    submittedAt,
    assignedReviewerUserId = null,
    assignedReviewerDisplayName = null,
    documentCount,
    pendingDocumentReviewCount,
  } = projection;
  if ((applicationCode !== null && (typeof applicationCode !== 'string' || applicationCode.length > 80))
    || typeof proposedName !== 'string' || proposedName.length > 200
    || (estateType !== null && (typeof estateType !== 'string' || estateType.length > 80))
    || (state !== null && (typeof state !== 'string' || state.length > 100))
    || (lga !== null && (typeof lga !== 'string' || lga.length > 100))
    || !['string', 'number'].includes(typeof applicantUserId)
    || typeof applicantDisplayName !== 'string' || applicantDisplayName.length > 200
    || !validTimestamp(submittedAt, true)
    || (assignedReviewerUserId !== null && !['string', 'number'].includes(typeof assignedReviewerUserId))
    || (assignedReviewerDisplayName !== null && (typeof assignedReviewerDisplayName !== 'string' || assignedReviewerDisplayName.length > 200))
    || !Number.isSafeInteger(documentCount) || documentCount < 0
    || !Number.isSafeInteger(pendingDocumentReviewCount) || pendingDocumentReviewCount < 0
    || pendingDocumentReviewCount > documentCount) {
    throw new EstateApplicationQueueError('INVALID_PROJECTION', 'The application summary contains invalid display fields.');
  }
  if (String(applicantUserId) !== String(record.applicantUserId)
    || new Date(submittedAt).toISOString() !== new Date(record.submittedAt).toISOString()) {
    throw new EstateApplicationQueueError('PROJECTION_RECORD_MISMATCH', 'The projected applicant or submission timestamp does not match the scoped application.');
  }
  return Object.freeze({
    id: record.id,
    applicationCode,
    proposedName,
    estateType,
    location: Object.freeze({ state, lga }),
    applicant: Object.freeze({ userId: applicantUserId, displayName: applicantDisplayName }),
    status: record.status,
    submittedAt,
    assignedReviewer: assignedReviewerUserId === null ? null : Object.freeze({ userId: assignedReviewerUserId, displayName: assignedReviewerDisplayName }),
    documentSummary: Object.freeze({ count: documentCount, pendingReview: pendingDocumentReviewCount }),
  });
}

/** List platform applications only within the reviewer's authorized queue scope. */
function createEstateApplicationQueueUseCase({
  transaction,
  requirePlatformPermission,
  queryEstateApplications,
  canReviewApplication,
  projectEstateApplicationForReviewer,
} = {}) {
  const ports = { transaction, requirePlatformPermission, queryEstateApplications, canReviewApplication, projectEstateApplicationForReviewer };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new EstateApplicationQueueError('MISSING_ADAPTER', `Application queue adapters are required: ${missing.join(', ')}.`);

  return async function listEstateApplications({ actorUserId, query } = {}) {
    if (!actorUserId) throw new EstateApplicationQueueError('UNAUTHENTICATED', 'An authenticated reviewer is required.');
    const normalized = normalizeApplicationQueueQuery(query);
    return transaction(async (tx) => {
      const platformContext = await requirePlatformPermission(actorUserId, 'estate_applications.review', tx);
      if (!platformContext) throw new EstateApplicationQueueError('PERMISSION_DENIED', 'The actor cannot view the estate application queue.');
      // Query adapter must enforce review assignment scope before searching, counting and paginating.
      const result = await queryEstateApplications(tx, { platformContext, ...normalized });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || ((normalized.page - 1) * normalized.pageSize >= result.total && result.items.length > 0)) {
        throw new EstateApplicationQueueError('INVALID_REPOSITORY_RESULT', 'The queue query must return a bounded page and authorized total.');
      }
      const seen = new Set();
      const items = [];
      for (const record of result.items) {
        if (!record?.id || !QueueStatuses.includes(record.status) || !validTimestamp(record.submittedAt, true)) {
          throw new EstateApplicationQueueError('INVALID_REPOSITORY_RESULT', 'The queue returned an invalid application record.');
        }
        const key = String(record.id);
        if (seen.has(key)) throw new EstateApplicationQueueError('DUPLICATE_REPOSITORY_RESULT', 'The queue returned a duplicate application.');
        seen.add(key);
        if (await canReviewApplication({ actorUserId, platformContext, application: record, tx }) !== true) {
          throw new EstateApplicationQueueError('REVIEW_SCOPE_VIOLATION', 'The repository returned an application outside the reviewer scope.');
        }
        const projection = await projectEstateApplicationForReviewer({ actorUserId, platformContext, application: record, tx });
        items.push(sanitizeApplicationProjection(record, projection));
      }
      return Object.freeze({
        items: Object.freeze(items),
        page: normalized.page,
        pageSize: normalized.pageSize,
        total: result.total,
        totalPages: Math.ceil(result.total / normalized.pageSize),
      });
    });
  };
}

module.exports = {
  EstateApplicationQueueError,
  QueueStatuses,
  createEstateApplicationQueueUseCase,
  normalizeApplicationQueueQuery,
  sanitizeApplicationProjection,
};
