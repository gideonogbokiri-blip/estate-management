const { JoinRequestDecision, planJoinRequestDecision } = require('./resident-membership');

class ResidentJoinRequestDecisionUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResidentJoinRequestDecisionUseCaseError';
    this.code = code;
  }
}

function createResidentJoinRequestDecisionUseCase({
  transaction,
  requireEstatePermission,
  findJoinRequestForUpdate,
  findPropertyInEstate,
  commitDecisionEffects,
  appendAuditEvent,
  enqueueApplicantNotification,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    transaction,
    requireEstatePermission,
    findJoinRequestForUpdate,
    findPropertyInEstate,
    commitDecisionEffects,
    appendAuditEvent,
    enqueueApplicantNotification,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new ResidentJoinRequestDecisionUseCaseError('MISSING_ADAPTER', `Join-request decision adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new ResidentJoinRequestDecisionUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function decideResidentJoinRequest({ actorUserId, estateId, requestId, decision, reason } = {}) {
    if (!actorUserId || !estateId || !requestId) {
      throw new ResidentJoinRequestDecisionUseCaseError('INVALID_DECISION_INPUT', 'Reviewer, estate context, and request are required.');
    }
    if (![JoinRequestDecision.APPROVE, JoinRequestDecision.REJECT].includes(decision)) {
      throw new ResidentJoinRequestDecisionUseCaseError('INVALID_DECISION', 'Choose approve or reject.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'resident_membership.review', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new ResidentJoinRequestDecisionUseCaseError('ESTATE_ACCESS_DENIED', 'The reviewer is not authorized for this estate.');
      }

      const request = await findJoinRequestForUpdate(tx, { requestId, estateContext });
      if (!request) {
        throw new ResidentJoinRequestDecisionUseCaseError('REQUEST_NOT_FOUND', 'The join request was not found.');
      }
      if (request.estateId !== estateContext.estateId) {
        throw new ResidentJoinRequestDecisionUseCaseError('REQUEST_NOT_FOUND', 'The join request was not found.');
      }

      const property = decision === JoinRequestDecision.APPROVE && request.propertyId
        ? await findPropertyInEstate(tx, { propertyId: request.propertyId, estateContext })
        : null;
      if (decision === JoinRequestDecision.APPROVE && request.propertyId && !property) {
        throw new ResidentJoinRequestDecisionUseCaseError('PROPERTY_NOT_FOUND', 'The requested property was not found in this estate.');
      }

      const plan = planJoinRequestDecision(request, { decision, actorUserId, reason, property, now: clock() });
      const result = await commitDecisionEffects(tx, plan);
      await appendAuditEvent(tx, plan.auditEvent);
      if (decision === JoinRequestDecision.REJECT) {
        await enqueueApplicantNotification(tx, {
          requestId,
          applicantUserId: request.userId,
          estateId,
          decision,
          message: reason.trim(),
          occurredAt: plan.auditEvent.occurredAt,
        });
      }
      return Object.freeze({ requestId: plan.requestId, status: plan.nextStatus, result });
    });
  };
}

module.exports = { ResidentJoinRequestDecisionUseCaseError, createResidentJoinRequestDecisionUseCase };
