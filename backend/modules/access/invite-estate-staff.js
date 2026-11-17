const { planStaffInvitation } = require('./staff-invitation');

class StaffInvitationUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StaffInvitationUseCaseError';
    this.code = code;
  }
}

function normalizeEmail(value) {
  if (typeof value !== 'string') return null;
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return null;
  return email;
}

/** Invite an existing Zvend user under an estate-scoped, actor-delegable role. */
function createEstateStaffInvitationUseCase({
  transaction,
  requireEstatePermission,
  resolveInvitableZvendUser,
  loadDelegableEstateRole,
  getStaffInvitationPolicy,
  checkStaffCapacity,
  findEstateMembership,
  findPendingInvitationForUpdate,
  generateInvitationId,
  createInvitation,
  enqueueInvitationNotice,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    resolveInvitableZvendUser,
    loadDelegableEstateRole,
    getStaffInvitationPolicy,
    checkStaffCapacity,
    findEstateMembership,
    findPendingInvitationForUpdate,
    generateInvitationId,
    createInvitation,
    enqueueInvitationNotice,
    appendAuditEvent,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) {
    throw new StaffInvitationUseCaseError('MISSING_ADAPTER', `Staff invitation adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') throw new StaffInvitationUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function inviteEstateStaff({ actorUserId, estateId, email, roleId } = {}) {
    const normalizedEmail = normalizeEmail(email);
    if (!actorUserId || !estateId || !roleId || !normalizedEmail) {
      throw new StaffInvitationUseCaseError('INVALID_INPUT', 'Authenticated actor, estate, valid account email and estate role are required.');
    }

    return transaction(async (tx) => {
      const estateContext = await requireEstatePermission(actorUserId, estateId, 'staff.invite', tx);
      if (!estateContext || estateContext.estateId !== estateId) {
        throw new StaffInvitationUseCaseError('ESTATE_ACCESS_DENIED', 'The actor cannot invite staff to this estate.');
      }
      const policy = await getStaffInvitationPolicy(tx, { estateContext });
      if (!policy || policy.acceptingInvitations !== true
        || !Number.isSafeInteger(policy.invitationLifetimeMs) || policy.invitationLifetimeMs <= 0) {
        throw new StaffInvitationUseCaseError('INVITATIONS_DISABLED', 'Staff invitations are unavailable under the current estate policy.');
      }

      // The identity adapter must return an active, verified existing account; callers cannot create parallel users here.
      const invitee = await resolveInvitableZvendUser(tx, { email: normalizedEmail });
      if (!invitee || invitee.invitable !== true || !invitee.id) {
        throw new StaffInvitationUseCaseError('INVITEE_NOT_ELIGIBLE', 'This email is not eligible for an estate staff invitation.');
      }

      const role = await loadDelegableEstateRole(tx, { estateContext, roleId });
      if (!role || String(role.id) !== String(roleId)) {
        throw new StaffInvitationUseCaseError('ROLE_NOT_DELEGABLE', 'Choose an estate role that you are authorized to delegate.');
      }
      const capacity = await checkStaffCapacity(tx, { estateContext, inviteeUserId: invitee.id, role });
      if (capacity !== true) {
        throw new StaffInvitationUseCaseError('STAFF_CAPACITY_UNAVAILABLE', 'The estate cannot add this staff invitation under its current plan or access policy.');
      }

      const membership = await findEstateMembership(tx, { estateContext, userId: invitee.id });
      if (membership) {
        throw new StaffInvitationUseCaseError('MEMBERSHIP_EXISTS', 'This account already has an estate membership; use the membership access workflow.');
      }
      const pending = await findPendingInvitationForUpdate(tx, { estateContext, inviteeUserId: invitee.id });
      if (pending) {
        throw new StaffInvitationUseCaseError('INVITATION_EXISTS', 'A pending estate invitation already exists for this account.');
      }

      const createdAt = clock();
      const createdTime = new Date(createdAt).getTime();
      if (Number.isNaN(createdTime)) throw new StaffInvitationUseCaseError('INVALID_CLOCK_VALUE', 'The clock must return a valid timestamp.');
      const invitationId = await generateInvitationId(tx);
      const plan = planStaffInvitation({
        invitationId,
        actorUserId,
        estateId,
        inviteeUserId: invitee.id,
        role,
        now: createdAt,
        expiresAt: new Date(createdTime + policy.invitationLifetimeMs),
      });
      const created = await createInvitation(tx, plan.invitation);
      const persistedPermissions = Array.isArray(created?.permissionIds) ? [...created.permissionIds].sort() : [];
      const plannedPermissions = [...plan.invitation.permissionIds].sort();
      if (!created || String(created.id) !== String(plan.invitation.id)
        || created.estateId !== estateId || created.inviteeUserId !== invitee.id
        || String(created.roleId) !== String(role.id) || created.status !== 'invited'
        || JSON.stringify(persistedPermissions) !== JSON.stringify(plannedPermissions)
        || (created.roleVersion ?? null) !== plan.invitation.roleVersion) {
        throw new StaffInvitationUseCaseError('INVALID_CREATE_RESULT', 'The repository did not persist the planned estate invitation.');
      }
      await enqueueInvitationNotice(tx, {
        estateId,
        invitationId: created.id,
        inviteeUserId: invitee.id,
        invitedByUserId: actorUserId,
      });
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        invitationId: created.id,
        estateId,
        roleId: role.id,
        status: 'invited',
        expiresAt: plan.invitation.expiresAt,
      });
    });
  };
}

module.exports = { StaffInvitationUseCaseError, createEstateStaffInvitationUseCase, normalizeEmail };
