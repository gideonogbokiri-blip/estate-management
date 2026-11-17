class ResidentJoinRequestReadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResidentJoinRequestReadError';
    this.code = code;
  }
}

function safeDetail(request, projected) {
  if (!projected || typeof projected !== 'object' || Array.isArray(projected)) {
    throw new ResidentJoinRequestReadError('PROJECTION_REQUIRED', 'An actor-authorized request detail projection is required.');
  }
  const applicantId = projected.applicant?.userId;
  if (applicantId !== request.userId) {
    throw new ResidentJoinRequestReadError('INVALID_PROJECTION', 'The projected applicant must match the request owner.');
  }
  const propertyId = projected.property?.id ?? null;
  if (propertyId !== (request.propertyId ?? null)) {
    throw new ResidentJoinRequestReadError('INVALID_PROJECTION', 'The projected property must match the requested property.');
  }
  const docs = projected.supportingDocuments || { count: 0, pendingReview: 0, categories: [] };
  if (!Number.isSafeInteger(docs.count) || docs.count < 0
    || !Number.isSafeInteger(docs.pendingReview) || docs.pendingReview < 0 || docs.pendingReview > docs.count
    || !Array.isArray(docs.categories) || docs.categories.some((category) => typeof category !== 'string')) {
    throw new ResidentJoinRequestReadError('INVALID_DOCUMENT_SUMMARY', 'Return document counts and categories only; private file references are prohibited.');
  }
  const decision = projected.decision || null;
  if (decision !== null && (typeof decision !== 'object' || Array.isArray(decision)
    || (decision.reason !== null && decision.reason !== undefined && typeof decision.reason !== 'string')
    || (decision.decidedAt !== null && decision.decidedAt !== undefined && typeof decision.decidedAt !== 'string'))) {
    throw new ResidentJoinRequestReadError('INVALID_DECISION_SUMMARY', 'Decision summary contains unsupported fields.');
  }

  return Object.freeze({
    id: request.id,
    estateId: request.estateId,
    status: request.status,
    relationship: request.relationship || null,
    submittedAt: request.submittedAt || null,
    applicant: Object.freeze({ userId: applicantId, displayName: projected.applicant.displayName || null }),
    requestedProperty: projected.property ? Object.freeze({ id: propertyId, label: projected.property.label || null }) : null,
    applicantNote: typeof projected.applicantNote === 'string' ? projected.applicantNote : null,
    supportingDocuments: Object.freeze({
      count: docs.count,
      pendingReview: docs.pendingReview,
      categories: Object.freeze([...new Set(docs.categories)]),
    }),
    decision: decision ? Object.freeze({ reason: decision.reason || null, decidedAt: decision.decidedAt || null }) : null,
  });
}

function createResidentJoinRequestReadUseCase({
  transaction,
  requireEstatePermission,
  findReviewerJoinRequest,
  findApplicantJoinRequest,
  projectJoinRequestDetailForActor,
} = {}) {
  const ports = { transaction, requireEstatePermission, findReviewerJoinRequest, findApplicantJoinRequest, projectJoinRequestDetailForActor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new ResidentJoinRequestReadError('MISSING_ADAPTER', `Join-request detail adapters are required: ${missing.join(', ')}.`);

  return async function readResidentJoinRequest({ actorUserId, requestId, estateId } = {}) {
    if (!actorUserId || !requestId) throw new ResidentJoinRequestReadError('INVALID_INPUT', 'Actor and request are required.');
    return transaction(async (tx) => {
      let request;
      let estateContext = null;
      if (estateId) {
        estateContext = await requireEstatePermission(actorUserId, estateId, 'resident_membership.review', tx);
        if (!estateContext || estateContext.estateId !== estateId) {
          throw new ResidentJoinRequestReadError('ESTATE_ACCESS_DENIED', 'The actor cannot review resident requests in this estate.');
        }
        request = await findReviewerJoinRequest(tx, { requestId, estateContext });
        if (!request || request.estateId !== estateId) {
          throw new ResidentJoinRequestReadError('REQUEST_NOT_FOUND', 'The join request was not found.');
        }
      } else {
        request = await findApplicantJoinRequest(tx, { requestId, applicantUserId: actorUserId });
        if (!request || request.userId !== actorUserId) {
          throw new ResidentJoinRequestReadError('REQUEST_NOT_FOUND', 'The join request was not found.');
        }
      }
      const projected = await projectJoinRequestDetailForActor({ actorUserId, estateContext, request, tx });
      return safeDetail(request, projected);
    });
  };
}

module.exports = { ResidentJoinRequestReadError, createResidentJoinRequestReadUseCase, safeDetail };
