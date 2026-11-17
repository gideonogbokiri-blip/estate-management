const { planJoinRequestCreation } = require('./resident-membership');

class ResidentJoinRequestCreationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResidentJoinRequestCreationError';
    this.code = code;
  }
}

/** Create a resident's own request using existing identity, file and estate-policy adapters. */
function createResidentJoinRequestUseCase({
  transaction,
  getJoinRequestPolicy,
  findPropertyInEstate,
  verifyApplicantCanRequest,
  findOpenJoinRequestForUpdate,
  verifyApplicantDocuments,
  generateJoinRequestId,
  createJoinRequest,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    getJoinRequestPolicy,
    verifyApplicantCanRequest,
    findOpenJoinRequestForUpdate,
    verifyApplicantDocuments,
    generateJoinRequestId,
    createJoinRequest,
    appendAuditEvent,
  };
  if (typeof findPropertyInEstate === 'function') ports.findPropertyInEstate = findPropertyInEstate;
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) {
    throw new ResidentJoinRequestCreationError('MISSING_ADAPTER', `Join request creation adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new ResidentJoinRequestCreationError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function createResidentJoinRequest({
    applicantUserId,
    estateId,
    propertyId = null,
    relationship,
    note = '',
    evidenceDocumentIds = [],
  } = {}) {
    if (!applicantUserId || !estateId) {
      throw new ResidentJoinRequestCreationError('INVALID_CREATION_INPUT', 'The authenticated applicant and estate are required.');
    }
    if (propertyId && typeof findPropertyInEstate !== 'function') {
      throw new ResidentJoinRequestCreationError('MISSING_ADAPTER', 'Property-scoped requests require a same-estate property lookup adapter.');
    }

    return transaction(async (tx) => {
      const policy = await getJoinRequestPolicy(tx, { estateId, relationship });
      if (!policy || policy.acceptingRequests !== true
        || !Array.isArray(policy.allowedRelationships)
        || !policy.allowedRelationships.includes(relationship)) {
        throw new ResidentJoinRequestCreationError('JOIN_REQUEST_NOT_ALLOWED', 'This estate is not accepting this type of join request.');
      }

      let property = null;
      if (propertyId) {
        property = await findPropertyInEstate(tx, { estateId, propertyId });
        if (!property || property.estateId !== estateId || String(property.id) !== String(propertyId)) {
          throw new ResidentJoinRequestCreationError('PROPERTY_NOT_FOUND', 'The selected property was not found in this estate.');
        }
      }

      const eligibility = await verifyApplicantCanRequest(tx, {
        applicantUserId, estateId, property, relationship,
      });
      if (eligibility !== true) {
        throw new ResidentJoinRequestCreationError('APPLICANT_NOT_ELIGIBLE', 'The applicant cannot request membership under the estate policy.');
      }

      // This lookup must lock the uniqueness scope (estate, applicant, property, relationship).
      const existing = await findOpenJoinRequestForUpdate(tx, {
        applicantUserId, estateId, propertyId: property?.id ?? null, relationship,
      });
      if (existing) {
        throw new ResidentJoinRequestCreationError('OPEN_REQUEST_EXISTS', 'An open request already exists for this estate and property relationship.');
      }

      if (!Array.isArray(evidenceDocumentIds) || evidenceDocumentIds.length > 10) {
        throw new ResidentJoinRequestCreationError('INVALID_EVIDENCE_REFERENCES', 'Provide up to ten private document references.');
      }
      const evidenceValid = await verifyApplicantDocuments(tx, {
        applicantUserId, estateId, documentIds: evidenceDocumentIds,
      });
      if (evidenceValid !== true) {
        throw new ResidentJoinRequestCreationError('INVALID_EVIDENCE_REFERENCES', 'Every evidence document must be authorized for this applicant and request.');
      }

      const requestId = await generateJoinRequestId(tx);
      const plan = planJoinRequestCreation({
        requestId,
        applicantUserId,
        estateId,
        property,
        relationship,
        note,
        evidenceDocumentIds,
        now: clock(),
        policyAllowsRequest: true,
      });
      const created = await createJoinRequest(tx, plan.request);
      if (!created || String(created.id) !== String(plan.request.id)
        || created.userId !== applicantUserId || created.estateId !== estateId
        || created.status !== plan.request.status
        || (created.propertyId ?? null) !== (plan.request.propertyId ?? null)) {
        throw new ResidentJoinRequestCreationError('INVALID_CREATE_RESULT', 'The repository did not persist the planned request in the selected estate.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      // Evidence references stay inside trusted persistence/file adapters.
      return Object.freeze({ requestId: plan.request.id, status: plan.request.status, submittedAt: plan.request.submittedAt });
    });
  };
}

module.exports = { ResidentJoinRequestCreationError, createResidentJoinRequestUseCase };
