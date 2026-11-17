const { ApplicationStatus, Decision } = require('../onboarding/application-decision');
const { createEstateFromApproval } = require('./estate');

class ApprovedEstateCommitError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ApprovedEstateCommitError';
    this.code = code;
  }
}

/** Bind the approval decision plan to repositories while requiring atomic estate and first-admin creation. */
function createApprovedEstateCommitter({
  createUniqueEstateCode,
  generateEstateId,
  createEstateRecord,
  createInitialAdministratorMembership,
} = {}) {
  const ports = { createUniqueEstateCode, generateEstateId, createEstateRecord, createInitialAdministratorMembership };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new ApprovedEstateCommitError('MISSING_ADAPTER', `Estate commit adapters are required: ${missing.join(', ')}.`);

  return async function commitApprovedEstate(tx, plan, { application, approvedByUserId, timezone, currency } = {}) {
    if (!tx || plan?.decision !== Decision.APPROVE || !application?.id || !approvedByUserId) {
      throw new ApprovedEstateCommitError('INVALID_APPROVAL_PLAN', 'A transaction, approved application and approval plan are required.');
    }
    if (String(application.id) !== String(plan.applicationId) || application.status !== ApplicationStatus.APPROVED) {
      throw new ApprovedEstateCommitError('APPLICATION_STATE_MISMATCH', 'The committed application must match the approved plan.');
    }
    const code = await createUniqueEstateCode(tx, { application });
    const estate = createEstateFromApproval({
      estateId: await generateEstateId(tx),
      application,
      approvedByUserId,
      estateCode: code,
      now: plan.auditEvent.occurredAt,
      timezone,
      currency,
    });
    const persistedEstate = await createEstateRecord(tx, estate);
    if (!persistedEstate?.id || String(persistedEstate.id) !== String(estate.id)
      || persistedEstate.status !== 'active'
      || String(persistedEstate.approvedApplicationId) !== String(application.id)) {
      throw new ApprovedEstateCommitError('ESTATE_COMMIT_FAILED', 'The estate repository did not persist the approved estate as planned.');
    }

    const membershipEffect = plan.effects.find((effect) => effect.type === 'estate.membership.create_initial_administrator');
    if (!membershipEffect || String(membershipEffect.applicationId) !== String(application.id)) {
      throw new ApprovedEstateCommitError('INITIAL_ADMIN_EFFECT_MISSING', 'Approval must include the initial estate administrator assignment.');
    }
    const membership = await createInitialAdministratorMembership(tx, {
      estateId: persistedEstate.id,
      userId: membershipEffect.userId,
      roleKey: membershipEffect.roleKey,
      assignedByUserId: membershipEffect.assignedByUserId,
      assignedAt: membershipEffect.assignedAt,
    });
    if (!membership?.id || String(membership.estateId) !== String(persistedEstate.id)
      || String(membership.userId) !== String(membershipEffect.userId)
      || membership.status !== 'active'
      || membership.roleKey !== membershipEffect.roleKey) {
      throw new ApprovedEstateCommitError('INITIAL_ADMIN_COMMIT_FAILED', 'The initial administrator membership was not persisted as active.');
    }
    return Object.freeze({ estate: persistedEstate, initialAdministratorMembership: membership });
  };
}

module.exports = { ApprovedEstateCommitError, createApprovedEstateCommitter };
