const { JoinRequestStatus, OccupantRelationship } = require('./resident-membership');

const projectionFields = new Set(['id', 'userId', 'propertyId', 'applicantName', 'applicantEmail', 'propertyLabel', 'relationship', 'submittedAt', 'status']);

function safeJoinRequestSummary(request, projection) {
  const hasValidId = (value) => ['string', 'number'].includes(typeof value) && String(value).trim() !== '';
  if (!hasValidId(request?.id) || !hasValidId(request?.userId)
    || (request.propertyId !== null && request.propertyId !== undefined && !hasValidId(request.propertyId))
    || !projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !projectionFields.has(field))
    || projection.id !== request.id || String(projection.userId) !== String(request.userId)
    || String(projection.propertyId ?? '') !== String(request.propertyId ?? '')
    || projection.status !== request.status
    || projection.relationship !== request.relationship || projection.submittedAt !== request.submittedAt) {
    throw new ResidentJoinRequestListError('INVALID_PROJECTION', 'Join-request status, relationship and timestamp must match the source record.');
  }
  const isoDate = typeof request.submittedAt === 'string'
    && !Number.isNaN(Date.parse(request.submittedAt))
    && new Date(request.submittedAt).toISOString() === request.submittedAt;
  if (!Object.values(JoinRequestStatus).includes(projection.status)
    || !Object.values(OccupantRelationship).includes(projection.relationship) || !isoDate
    || typeof projection.applicantName !== 'string' || !projection.applicantName.trim() || projection.applicantName.length > 160
    || (projection.applicantEmail !== null && projection.applicantEmail !== undefined
      && (typeof projection.applicantEmail !== 'string' || projection.applicantEmail.length > 254))
    || (projection.propertyLabel !== null && projection.propertyLabel !== undefined
      && (typeof projection.propertyLabel !== 'string' || projection.propertyLabel.length > 160))) {
    throw new ResidentJoinRequestListError('INVALID_PROJECTION', 'Join-request labels and source fields are invalid.');
  }
  if (request.propertyId === null || request.propertyId === undefined) {
    if (projection.propertyLabel !== null && projection.propertyLabel !== undefined) {
      throw new ResidentJoinRequestListError('INVALID_PROJECTION', 'A request without a property cannot have a property label.');
    }
  } else if (projection.propertyLabel === null || projection.propertyLabel === undefined || !projection.propertyLabel.trim()) {
    throw new ResidentJoinRequestListError('INVALID_PROJECTION', 'Property requests require an authorized property label.');
  }
  return Object.freeze({
    id: request.id,
    applicantName: projection.applicantName.trim(),
    applicantEmail: projection.applicantEmail?.trim() || null,
    propertyLabel: projection.propertyLabel?.trim() || null,
    relationship: projection.relationship,
    submittedAt: request.submittedAt,
    status: request.status,
  });
}

class ResidentJoinRequestListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResidentJoinRequestListError';
    this.code = code;
  }
}

function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function normalizeJoinRequestQuery(query = {}) {
  if (!query || typeof query !== 'object' || Array.isArray(query)) {
    throw new ResidentJoinRequestListError('INVALID_QUERY', 'Join-request filters must be an object.');
  }
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 25 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    throw new ResidentJoinRequestListError('INVALID_PAGINATION', 'Page must be positive and page size must be between 1 and 100.');
  }
  if (query.status && !Object.values(JoinRequestStatus).includes(query.status)) {
    throw new ResidentJoinRequestListError('INVALID_STATUS_FILTER', 'Choose a supported join-request status.');
  }
  if (query.relationship && !Object.values(OccupantRelationship).includes(query.relationship)) {
    throw new ResidentJoinRequestListError('INVALID_RELATIONSHIP_FILTER', 'Choose a supported resident relationship.');
  }
  for (const field of ['submittedFrom', 'submittedTo']) {
    if (query[field] !== undefined && query[field] !== '' && !validDate(query[field])) {
      throw new ResidentJoinRequestListError('INVALID_DATE_FILTER', `${field} must be a valid YYYY-MM-DD date.`);
    }
  }
  if (query.submittedFrom && query.submittedTo && query.submittedFrom > query.submittedTo) {
    throw new ResidentJoinRequestListError('INVALID_DATE_RANGE', 'Submission date range is reversed.');
  }
  if (query.propertyId !== undefined && query.propertyId !== null && query.propertyId !== '') {
    if (!['string', 'number'].includes(typeof query.propertyId) || !String(query.propertyId).trim()) {
      throw new ResidentJoinRequestListError('INVALID_PROPERTY_FILTER', 'Property filter is invalid.');
    }
  }
  if (query.search !== undefined && typeof query.search !== 'string') {
    throw new ResidentJoinRequestListError('INVALID_SEARCH', 'Search must be text.');
  }
  const search = query.search?.trim() || '';
  if (search.length > 100) throw new ResidentJoinRequestListError('INVALID_SEARCH', 'Search text must be 100 characters or fewer.');

  const filters = {};
  for (const field of ['status', 'relationship', 'submittedFrom', 'submittedTo']) {
    if (query[field]) filters[field] = query[field];
  }
  if (query.propertyId !== undefined && query.propertyId !== null && query.propertyId !== '') filters.propertyId = query.propertyId;
  if (search) filters.search = search;
  return Object.freeze({ page, pageSize, filters: Object.freeze(filters) });
}

function createResidentJoinRequestListUseCase({
  transaction,
  requireEstatePermission,
  queryJoinRequests,
  projectJoinRequestForActor,
} = {}) {
  const ports = { transaction, requireEstatePermission, queryJoinRequests, projectJoinRequestForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new ResidentJoinRequestListError('MISSING_ADAPTER', `Join-request list adapters are required: ${missing.join(', ')}.`);

  return async function listResidentJoinRequests({ actorUserId, estateId, query } = {}) {
    if (!actorUserId || !estateId) throw new ResidentJoinRequestListError('INVALID_INPUT', 'Actor and estate context are required.');
    const normalized = normalizeJoinRequestQuery(query);
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'resident_membership.review', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new ResidentJoinRequestListError('ESTATE_ACCESS_DENIED', 'The actor cannot review resident requests in this estate.');
      }
      // The adapter scopes by estate/reviewer before filters, counts or pagination.
      const result = await queryJoinRequests(tx, { estateContext, ...normalized });
      if (!result || !Array.isArray(result.items) || result.items.length > normalized.pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new ResidentJoinRequestListError('INVALID_REPOSITORY_RESULT', 'The request query must return a bounded page and authorized total.');
      }
      if (result.items.some((request) => !request?.id || request.estateId !== estateId)) {
        throw new ResidentJoinRequestListError('ESTATE_SCOPE_VIOLATION', 'The repository returned a request outside the selected estate.');
      }
      const items = [];
      for (const request of result.items) {
        const projection = await projectJoinRequestForActor({ actorUserId, estateContext, request, tx });
        items.push(safeJoinRequestSummary(request, projection));
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

module.exports = { ResidentJoinRequestListError, createResidentJoinRequestListUseCase, normalizeJoinRequestQuery, safeJoinRequestSummary };
