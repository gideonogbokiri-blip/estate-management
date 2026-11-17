const { Decision, planApplicationDecision } = require('./application-decision');

class EstateApplicationApprovalError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationApprovalError';
    this.code = code;
  }
}

/**
 * Commit estate approval through injected Zvend adapters.
 * The adapters must share one database transaction and preserve the source
 * application's authorization, identity, persistence, and audit conventions.
 */
function createEstateApplicationApprovalUseCase({
  requirePlatformPermission,
  transaction,
  findApplicationForDecision,
  findEligibleInitialAdministrator,
  commitDecisionEffects,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    requirePlatformPermission,
    transaction,
    findApplicationForDecision,
    findEligibleInitialAdministrator,
    commitDecisionEffects,
    appendAuditEvent,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new EstateApplicationApprovalError('MISSING_ADAPTER', `Approval adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new EstateApplicationApprovalError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function approveEstateApplication({ actorUserId, applicationId, initialAdministratorUserId } = {}) {
    if (!actorUserId || !applicationId || !initialAdministratorUserId) {
      throw new EstateApplicationApprovalError('INVALID_APPROVAL_INPUT', 'Reviewer, application, and initial administrator are required.');
    }

    return transaction(async (tx) => {
      await requirePlatformPermission(actorUserId, 'estate_applications.approve', tx);
      // This lookup must lock the application row and enforce reviewer scope.
      const application = await findApplicationForDecision(tx, { applicationId, actorUserId });
      if (!application) {
        throw new EstateApplicationApprovalError('APPLICATION_NOT_FOUND', "The application was not found in the reviewer's scope.");
      }

      // Identity and eligibility are checked against the existing Zvend user store.
      const initialAdministrator = await findEligibleInitialAdministrator(tx, {
        userId: initialAdministratorUserId,
        application,
      });
      if (!initialAdministrator
        || String(initialAdministrator.userId) !== String(initialAdministratorUserId)) {
        throw new EstateApplicationApprovalError('INITIAL_ADMIN_NOT_ELIGIBLE', 'Choose an eligible existing Zvend user as the initial estate administrator.');
      }

      const plan = planApplicationDecision(application, {
        decision: Decision.APPROVE,
        actorUserId,
        initialAdministratorUserId: initialAdministrator.userId,
        now: clock(),
      });

      // Pass the locked, now-approved application into the persistence seam so estate fields
      // and a server-generated estate code are derived from trusted reviewed state.
      const approvedApplication = Object.freeze({ ...application, status: plan.nextStatus });

      // The adapter applies application, estate, and initial membership effects atomically.
      const result = await commitDecisionEffects(tx, plan, {
        application: approvedApplication,
        approvedByUserId: actorUserId,
      });
      if (!result?.estate?.id || result.estate.status !== 'active'
        || String(result.estate.approvedApplicationId) !== String(application.id)
        || !result.initialAdministratorMembership?.id
        || String(result.initialAdministratorMembership.userId) !== String(initialAdministrator.userId)
        || String(result.initialAdministratorMembership.estateId) !== String(result.estate.id)
        || result.initialAdministratorMembership.status !== 'active'
        || result.initialAdministratorMembership.roleKey !== 'estate_administrator') {
        throw new EstateApplicationApprovalError('INVALID_COMMIT_RESULT', 'Approval must atomically create an active estate and its initial administrator membership.');
      }
      for (const auditEvent of plan.auditEvents) await appendAuditEvent(tx, auditEvent);
      await appendAuditEvent(tx, Object.freeze({
        actorUserId,
        scope: 'estate',
        estateId: result.estate.id,
        action: 'staff.initial_administrator.assigned',
        targetType: 'estate_membership',
        targetId: result.initialAdministratorMembership.id,
        outcome: 'success',
        occurredAt: plan.auditEvent.occurredAt,
        metadata: Object.freeze({ userId: initialAdministrator.userId, roleKey: 'estate_administrator' }),
      }));
      return Object.freeze({
        applicationId: plan.applicationId,
        status: plan.nextStatus,
        estateId: result.estate.id,
        initialAdministratorMembershipId: result.initialAdministratorMembership.id,
      });
    });
  };
}

module.exports = { EstateApplicationApprovalError, createEstateApplicationApprovalUseCase };
