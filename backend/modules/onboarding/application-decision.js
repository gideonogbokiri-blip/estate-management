const { EstateStatus } = require('./estate-lifecycle');

const ApplicationStatus = Object.freeze({
  DRAFT: 'draft',
  SUBMITTED: 'submitted',
  UNDER_REVIEW: 'under_review',
  MORE_INFORMATION_REQUIRED: 'more_information_required',
  APPROVED: 'approved',
  REJECTED: 'rejected',
});

const Decision = Object.freeze({
  APPROVE: 'approve',
  REJECT: 'reject',
  REQUEST_INFORMATION: 'request_information',
});

class ApplicationDecisionError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ApplicationDecisionError';
    this.code = code;
  }
}

/**
 * Plans a platform review decision without performing I/O or authorization.
 * The caller must atomically persist every returned effect and audit event.
 */
function planApplicationDecision(application, input) {
  if (!application?.id || !application.status) {
    throw new ApplicationDecisionError('INVALID_APPLICATION', 'A persisted application is required.');
  }

  const { decision, actorUserId, now, reason, initialAdministratorUserId } = input ?? {};
  if (!actorUserId) {
    throw new ApplicationDecisionError('MISSING_ACTOR', 'The authenticated reviewer is required.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new ApplicationDecisionError('INVALID_TIMESTAMP', 'A valid decision timestamp is required.');
  }
  if (application.status !== ApplicationStatus.UNDER_REVIEW) {
    throw new ApplicationDecisionError('INVALID_STATE', 'Only an application under review can receive a decision.');
  }

  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (![Decision.APPROVE, Decision.REJECT, Decision.REQUEST_INFORMATION].includes(decision)) {
    throw new ApplicationDecisionError('INVALID_DECISION', 'Choose approve, reject, or request_information.');
  }
  if (decision !== Decision.APPROVE && !normalizedReason) {
    throw new ApplicationDecisionError('REASON_REQUIRED', 'A reason is required for this decision.');
  }

  const decidedAt = new Date(now).toISOString();
  const statusByDecision = {
    [Decision.APPROVE]: ApplicationStatus.APPROVED,
    [Decision.REJECT]: ApplicationStatus.REJECTED,
    [Decision.REQUEST_INFORMATION]: ApplicationStatus.MORE_INFORMATION_REQUIRED,
  };
  const nextStatus = statusByDecision[decision];
  const effects = [{
    type: 'application.status_changed',
    applicationId: application.id,
    from: application.status,
    to: nextStatus,
    actorUserId,
    reason: normalizedReason || null,
    occurredAt: decidedAt,
  }];

  if (decision === Decision.APPROVE) {
    if (!initialAdministratorUserId) {
      throw new ApplicationDecisionError('INITIAL_ADMIN_REQUIRED', 'Select the initial estate administrator.');
    }
    effects.push(
      {
        type: 'estate.activate_from_application',
        applicationId: application.id,
        status: EstateStatus.ACTIVE,
        approvedByUserId: actorUserId,
        approvedAt: decidedAt,
      },
      {
        type: 'estate.membership.create_initial_administrator',
        applicationId: application.id,
        userId: initialAdministratorUserId,
        roleKey: 'estate_administrator',
        assignedByUserId: actorUserId,
        assignedAt: decidedAt,
      },
    );
  }

  const auditEvent = Object.freeze({
    actorUserId,
    scope: 'platform',
    action: `estate_application.${decision}`,
    targetType: 'estate_application',
    targetId: application.id,
    outcome: 'success',
    reason: normalizedReason || null,
    occurredAt: decidedAt,
  });
  return Object.freeze({
    transactionRequired: true,
    applicationId: application.id,
    decision,
    nextStatus,
    effects: Object.freeze(effects.map(Object.freeze)),
    auditEvent,
    auditEvents: Object.freeze([auditEvent]),
  });
}

module.exports = {
  ApplicationDecisionError,
  ApplicationStatus,
  Decision,
  planApplicationDecision,
};
