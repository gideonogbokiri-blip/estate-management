class MyResidentJoinRequestListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MyResidentJoinRequestListError';
    this.code = code;
  }
}

const allowedStatuses = new Set(['submitted', 'approved', 'rejected', 'withdrawn']);
const allowedProjectionFields = new Set(['requestId', 'estateId', 'status', 'relationship', 'submittedAt', 'estateName', 'propertyLabel']);

function safeApplicantProjection(request, projection) {
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !allowedProjectionFields.has(field))) {
    throw new MyResidentJoinRequestListError('INVALID_PROJECTION', 'The applicant projection contains unsupported fields.');
  }
  if (String(projection.requestId) !== String(request.id)
    || String(projection.estateId) !== String(request.estateId)
    || projection.status !== request.status || !allowedStatuses.has(projection.status)) {
    throw new MyResidentJoinRequestListError('INVALID_PROJECTION', 'The applicant projection does not match the scoped request.');
  }
  for (const [field, maxLength] of [['relationship', 40], ['estateName', 120], ['propertyLabel', 160]]) {
    const value = projection[field];
    if (value !== null && value !== undefined && (typeof value !== 'string' || value.length > maxLength)) {
      throw new MyResidentJoinRequestListError('INVALID_PROJECTION', `${field} is not a safe display label.`);
    }
  }
  if (projection.submittedAt !== null && projection.submittedAt !== undefined
    && (typeof projection.submittedAt !== 'string' || Number.isNaN(Date.parse(projection.submittedAt)))) {
    throw new MyResidentJoinRequestListError('INVALID_PROJECTION', 'submittedAt must be a valid timestamp.');
  }
  return Object.freeze({
    requestId: request.id,
    estateId: request.estateId,
    status: request.status,
    relationship: projection.relationship ?? null,
    submittedAt: projection.submittedAt ?? null,
    estateName: projection.estateName ?? null,
    propertyLabel: projection.propertyLabel ?? null,
  });
}

function createMyResidentJoinRequestListUseCase({
  transaction,
  queryApplicantJoinRequests,
  projectApplicantJoinRequest,
} = {}) {
  const ports = { transaction, queryApplicantJoinRequests, projectApplicantJoinRequest };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new MyResidentJoinRequestListError('MISSING_ADAPTER', `My join-request list adapters are required: ${missing.join(', ')}.`);

  return async function listMyResidentJoinRequests({ actorUserId, page = 1, pageSize = 25 } = {}) {
    if (!actorUserId || !Number.isInteger(page) || page < 1
      || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new MyResidentJoinRequestListError('INVALID_QUERY', 'Authenticated applicant and bounded pagination are required.');
    }
    return transaction(async (tx) => {
      // Actor scope must be applied by the repository before count and pagination.
      const result = await queryApplicantJoinRequests(tx, { applicantUserId: actorUserId, page, pageSize });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new MyResidentJoinRequestListError('INVALID_LIST_RESULT', 'The applicant request repository returned an invalid page.');
      }
      const items = [];
      for (const request of result.items) {
        if (!request?.id || request.userId !== actorUserId || !request.estateId) {
          throw new MyResidentJoinRequestListError('CROSS_SCOPE_RESULT', 'The repository returned a request outside the authenticated applicant scope.');
        }
        const projection = await projectApplicantJoinRequest(tx, { applicantUserId: actorUserId, request });
        items.push(safeApplicantProjection(request, projection));
      }
      return Object.freeze({ items: Object.freeze(items), page, pageSize, total: result.total,
        totalPages: Math.ceil(result.total / pageSize) });
    });
  };
}

module.exports = { MyResidentJoinRequestListError, createMyResidentJoinRequestListUseCase, safeApplicantProjection };
