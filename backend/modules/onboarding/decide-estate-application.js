const { Decision, planApplicationDecision } = require('./application-decision');

class EstateApplicationDecisionUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationDecisionUseCaseError';
    this.code = code;
  }
}

function createEstateApplicationDecisionUseCase({
  requirePlatformPermission,
  transaction,
  findApplicationForDecision,
  commitDecisionEffects,
  appendAuditEvent,
  enqueueApplicantNotification,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    requirePlatformPermission,
    transaction,
    findApplicationForDecision,
    commitDecisionEffects,
    appendAuditEvent,
    enqueueApplicantNotification,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new EstateApplicationDecisionUseCaseError('MISSING_ADAPTER', `Review decision adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new EstateApplicationDecisionUseCaseError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function decideEstateApplication({ actorUserId, applicationId, decision, reason } = {}) {
    if (!actorUserId || !applicationId) {
      throw new EstateApplicationDecisionUseCaseError('INVALID_DECISION_INPUT', 'Reviewer and application are required.');
    }
    if (![Decision.REJECT, Decision.REQUEST_INFORMATION].includes(decision)) {
      throw new EstateApplicationDecisionUseCaseError('INVALID_DECISION', 'This use case accepts reject or request_information.');
    }

    return transaction(async (tx) => {
      await requirePlatformPermission(actorUserId, 'estate_applications.review', tx);
      const application = await findApplicationForDecision(tx, { applicationId, actorUserId });
      if (!application) {
        throw new EstateApplicationDecisionUseCaseError('APPLICATION_NOT_FOUND', "The application was not found in the reviewer's scope.");
      }
      if (!application.applicantUserId) {
        throw new EstateApplicationDecisionUseCaseError('INVALID_APPLICATION', 'The application has no applicant to notify.');
      }

      const plan = planApplicationDecision(application, { decision, actorUserId, reason, now: clock() });
      const result = await commitDecisionEffects(tx, plan);
      if (!result || String(result.id) !== String(application.id) || result.status !== plan.nextStatus) {
        throw new EstateApplicationDecisionUseCaseError('INVALID_COMMIT_RESULT', 'The repository did not persist the planned application decision.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      // Persist through the existing notification outbox in the same transaction.
      await enqueueApplicantNotification(tx, {
        applicationId,
        applicantUserId: application.applicantUserId,
        decision,
        message: reason.trim(),
        occurredAt: plan.auditEvent.occurredAt,
      });
      return Object.freeze({ applicationId: plan.applicationId, status: plan.nextStatus });
    });
  };
}

module.exports = { EstateApplicationDecisionUseCaseError, createEstateApplicationDecisionUseCase };
