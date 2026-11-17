const { ApplicationStatus } = require('./application-decision');

class EstateApplicationReviewerAssignmentError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationReviewerAssignmentError';
    this.code = code;
  }
}

function planReviewerAssignment(application, { actorUserId, reviewerUserId, now } = {}) {
  if (!application?.id || !application.status) {
    throw new EstateApplicationReviewerAssignmentError('INVALID_APPLICATION', 'A persisted application is required.');
  }
  if (!actorUserId || !reviewerUserId) {
    throw new EstateApplicationReviewerAssignmentError('INVALID_ASSIGNMENT', 'Assigner and reviewer are required.');
  }
  if (application.status !== ApplicationStatus.SUBMITTED) {
    throw new EstateApplicationReviewerAssignmentError('INVALID_STATE', 'Only a submitted application can be assigned.');
  }
  if (application.assignedReviewerUserId) {
    throw new EstateApplicationReviewerAssignmentError('ALREADY_ASSIGNED', 'This application already has an assigned reviewer.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new EstateApplicationReviewerAssignmentError('INVALID_TIMESTAMP', 'A valid assignment timestamp is required.');
  }

  const assignedAt = new Date(now).toISOString();
  return Object.freeze({
    transactionRequired: true,
    applicationId: application.id,
    reviewerUserId,
    assignedAt,
    effects: Object.freeze([Object.freeze({
      type: 'estate_application.reviewer_assigned',
      applicationId: application.id,
      fromReviewerUserId: null,
      toReviewerUserId: reviewerUserId,
      assignedByUserId: actorUserId,
      assignedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'platform',
      action: 'estate_application.reviewer_assigned',
      targetType: 'estate_application',
      targetId: application.id,
      outcome: 'success',
      occurredAt: assignedAt,
      metadata: Object.freeze({ reviewerUserId }),
    }),
  });
}

function createEstateApplicationReviewerAssignmentUseCase({
  requirePlatformPermission,
  transaction,
  findSubmittedApplicationForUpdate,
  findEligibleReviewer,
  commitReviewerAssignment,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { requirePlatformPermission, transaction, findSubmittedApplicationForUpdate, findEligibleReviewer, commitReviewerAssignment, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) {
    throw new EstateApplicationReviewerAssignmentError('MISSING_ADAPTER', `Reviewer-assignment adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new EstateApplicationReviewerAssignmentError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function assignEstateApplicationReviewer({ actorUserId, applicationId, reviewerUserId } = {}) {
    if (!actorUserId || !applicationId || !reviewerUserId) {
      throw new EstateApplicationReviewerAssignmentError('INVALID_ASSIGNMENT_INPUT', 'Assigner, application and reviewer are required.');
    }
    return transaction(async (tx) => {
      await requirePlatformPermission(actorUserId, 'estate_applications.assign_reviewer', tx);
      const application = await findSubmittedApplicationForUpdate(tx, { applicationId });
      if (!application) {
        throw new EstateApplicationReviewerAssignmentError('APPLICATION_NOT_FOUND', 'The submitted application was not found.');
      }
      const reviewer = await findEligibleReviewer(tx, { reviewerUserId, application });
      if (!reviewer || reviewer.userId !== reviewerUserId) {
        throw new EstateApplicationReviewerAssignmentError('REVIEWER_NOT_ELIGIBLE', 'Choose an existing user authorized to review estate applications.');
      }
      const plan = planReviewerAssignment(application, { actorUserId, reviewerUserId, now: clock() });
      const result = await commitReviewerAssignment(tx, plan);
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ applicationId, reviewerUserId, assignedAt: plan.assignedAt, result });
    });
  };
}

module.exports = {
  EstateApplicationReviewerAssignmentError,
  planReviewerAssignment,
  createEstateApplicationReviewerAssignmentUseCase,
};
