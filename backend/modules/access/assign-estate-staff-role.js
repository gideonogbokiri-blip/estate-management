const { planStaffRoleAssignment } = require('./staff-role-assignment');

class StaffRoleAssignmentUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StaffRoleAssignmentUseCaseError';
    this.code = code;
  }
}

/** Assign a trusted, delegable role to another estate member in one transaction. */
function createEstateStaffRoleAssignmentUseCase({
  transaction,
  requireEstatePermission,
  findMembershipForUpdate,
  loadDelegableRole,
  checkRoleAssignmentPolicy,
  commitRoleAssignment,
  enqueueAuthorizationInvalidation,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireEstatePermission, findMembershipForUpdate, loadDelegableRole, checkRoleAssignmentPolicy, commitRoleAssignment, enqueueAuthorizationInvalidation, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new StaffRoleAssignmentUseCaseError('MISSING_ADAPTER', `Staff role adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new StaffRoleAssignmentUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function assignEstateStaffRole({ actorUserId, estateId, membershipId, roleId, reason } = {}) {
    if (!actorUserId || !estateId || !membershipId || !roleId) {
      throw new StaffRoleAssignmentUseCaseError('INVALID_INPUT', 'Authenticated actor, estate, membership and role are required.');
    }
    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'staff.grant', tx);
      if (!estateContext || String(estateContext.estateId) !== String(estateId)) {
        throw new StaffRoleAssignmentUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot grant staff roles in this estate.');
      }
      const membership = await findMembershipForUpdate(tx, { membershipId, estateContext });
      if (!membership || String(membership.estateId) !== String(estateId)) {
        throw new StaffRoleAssignmentUseCaseError('MEMBERSHIP_NOT_FOUND', 'The membership was not found in this estate.');
      }
      if (String(membership.userId) === String(actorUserId)) {
        throw new StaffRoleAssignmentUseCaseError('SELF_ASSIGNMENT_FORBIDDEN', 'Members cannot change their own effective estate role.');
      }
      const grant = await loadDelegableRole(tx, { estateContext, roleId, actorUserId });
      if (!grant || String(grant.role?.id) !== String(roleId)) {
        throw new StaffRoleAssignmentUseCaseError('ROLE_NOT_FOUND', 'The selected role is unavailable in this estate.');
      }
      if (await checkRoleAssignmentPolicy(tx, { estateContext, actorUserId, membership, role: grant.role }) !== true) {
        throw new StaffRoleAssignmentUseCaseError('ROLE_POLICY_BLOCKED', 'The role change is not allowed under current estate policy.');
      }
      const plan = planStaffRoleAssignment({ membership, actorUserId, role: grant.role, delegablePermissionIds: grant.delegablePermissionIds, reason, now: clock() });
      const updated = await commitRoleAssignment(tx, plan);
      if (!updated || String(updated.id) !== String(membership.id) || String(updated.estateId) !== String(estateId)
        || String(updated.userId) !== String(membership.userId) || String(updated.roleId) !== String(grant.role.id)) {
        throw new StaffRoleAssignmentUseCaseError('INVALID_COMMIT_RESULT', 'The repository did not persist the planned role assignment.');
      }
      await enqueueAuthorizationInvalidation(tx, { estateId, userId: membership.userId, membershipId: membership.id, occurredAt: plan.assignment.occurredAt });
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ membershipId: membership.id, estateId, userId: membership.userId, roleId: grant.role.id, changedAt: plan.assignment.occurredAt });
    });
  };
}

module.exports = { StaffRoleAssignmentUseCaseError, createEstateStaffRoleAssignmentUseCase };
