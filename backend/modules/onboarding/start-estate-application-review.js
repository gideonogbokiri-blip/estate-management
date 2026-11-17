const { planApplicationReviewStart } = require('./application-lifecycle');

class EstateApplicationReviewStartError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationReviewStartError';
    this.code = code;
  }
}

/** Move a submitted application into review through the existing platform adapters. */
function createEstateApplicationReviewStartUseCase({
  requirePlatformPermission,
  transaction,
  findApplicationForReview,
  commitReviewStart,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    requirePlatformPermission,
    transaction,
    findApplicationForReview,
    commitReviewStart,
    appendAuditEvent,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new EstateApplicationReviewStartError('MISSING_ADAPTER', `Review-start adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new EstateApplicationReviewStartError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function startEstateApplicationReview({ actorUserId, applicationId } = {}) {
    if (!actorUserId || !applicationId) {
      throw new EstateApplicationReviewStartError('INVALID_REVIEW_INPUT', 'Reviewer and application are required.');
    }

    return transaction(async (tx) => {
      await requirePlatformPermission(actorUserId, 'estate_applications.review', tx);
      // This adapter must lock the record and enforce its assigned-reviewer scope.
      const application = await findApplicationForReview(tx, { applicationId, actorUserId });
      if (!application) {
        throw new EstateApplicationReviewStartError('APPLICATION_NOT_FOUND', 'The application was not found in the reviewer\'s scope.');
      }

      const plan = planApplicationReviewStart(application, { actorUserId, now: clock() });
      const result = await commitReviewStart(tx, plan);
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ applicationId: plan.applicationId, status: plan.nextStatus, result });
    });
  };
}

module.exports = { EstateApplicationReviewStartError, createEstateApplicationReviewStartUseCase };
