const { planStaffInvitationAcceptance } = require('./staff-invitation');

class StaffInvitationAcceptanceError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StaffInvitationAcceptanceError';
    this.code = code;
  }
}

/** Accept only the authenticated invitee's pending invitation for an active estate. */
function createEstateStaffInvitationAcceptanceUseCase({
  transaction,
  findInvitationForUpdate,
  findActiveEstate,
  findRoleForInvitation,
  verifyInviteeCanAccept,
  findEstateMembership,
  checkStaffCapacity,
  commitInvitationAcceptance,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    findInvitationForUpdate,
    findActiveEstate,
    findRoleForInvitation,
    verifyInviteeCanAccept,
    findEstateMembership,
    checkStaffCapacity,
    commitInvitationAcceptance,
    appendAuditEvent,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) {
    throw new StaffInvitationAcceptanceError('MISSING_ADAPTER', `Invitation acceptance adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') throw new StaffInvitationAcceptanceError('INVALID_CLOCK', 'A clock function is required.');

  return async function acceptEstateStaffInvitation({ actorUserId, estateId, invitationId } = {}) {
    if (!actorUserId || !estateId || !invitationId) {
      throw new StaffInvitationAcceptanceError('INVALID_INPUT', 'Authenticated invitee, estate and invitation are required.');
    }

    return transaction(async (tx) => {
      // The lookup must lock and scope by both estate and invitation before revealing any details.
      const invitation = await findInvitationForUpdate(tx, { estateId, invitationId });
      if (!invitation || String(invitation.estateId) !== String(estateId)
        || String(invitation.inviteeUserId) !== String(actorUserId)) {
        throw new StaffInvitationAcceptanceError('INVITATION_NOT_FOUND', 'The invitation was not found for this account.');
      }
      const estate = await findActiveEstate(tx, { estateId });
      const role = await findRoleForInvitation(tx, { estateId, roleId: invitation.roleId });
      const inviteeValid = await verifyInviteeCanAccept(tx, { actorUserId, estateId, invitation });
      if (inviteeValid !== true) {
        throw new StaffInvitationAcceptanceError('INVITEE_NOT_ELIGIBLE', 'This account cannot accept the estate invitation.');
      }

      const plan = planStaffInvitationAcceptance({
        invitation,
        actorUserId,
        estate,
        role,
        now: clock(),
      });

      const membership = await findEstateMembership(tx, { estateId, userId: actorUserId });
      if (membership) {
        throw new StaffInvitationAcceptanceError('MEMBERSHIP_EXISTS', 'This account already has an estate membership.');
      }
      const capacity = await checkStaffCapacity(tx, { estateId, inviteeUserId: actorUserId, role });
      if (capacity !== true) {
        throw new StaffInvitationAcceptanceError('STAFF_CAPACITY_UNAVAILABLE', 'The estate cannot activate this membership under its current plan or access policy.');
      }

      const committed = await commitInvitationAcceptance(tx, plan);
      if (!committed || String(committed.invitation?.id) !== String(invitationId)
        || committed.invitation?.status !== 'accepted'
        || !committed.membership?.id
        || String(committed.membership?.userId) !== String(actorUserId)
        || String(committed.membership?.estateId) !== String(estateId)
        || committed.membership?.status !== 'active'
        || String(committed.membership?.roleId) !== String(invitation.roleId)) {
        throw new StaffInvitationAcceptanceError('INVALID_COMMIT_RESULT', 'The repository did not atomically accept the invitation and activate the intended membership.');
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        invitationId,
        estateId,
        membershipId: committed.membership.id,
        roleId: invitation.roleId,
        status: 'active',
        acceptedAt: plan.acceptedAt,
      });
    });
  };
}

module.exports = { StaffInvitationAcceptanceError, createEstateStaffInvitationAcceptanceUseCase };
