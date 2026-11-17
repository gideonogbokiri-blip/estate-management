class StaffInvitationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StaffInvitationError';
    this.code = code;
  }
}

function validTime(value) {
  return value !== undefined && value !== null && value !== '' && !Number.isNaN(new Date(value).getTime());
}

/** Prepare an estate-scoped invitation for an existing Zvend identity and a server-approved delegable role. */
function planStaffInvitation({ invitationId, actorUserId, estateId, inviteeUserId, role, now, expiresAt } = {}) {
  if (!invitationId || !actorUserId || !estateId || !inviteeUserId) {
    throw new StaffInvitationError('INVALID_INVITATION', 'Invitation, actor, estate and existing invitee identities are required.');
  }
  if (!role?.id || (role.estateId && String(role.estateId) !== String(estateId))
    || role.status !== 'active' || role.delegable !== true || !Array.isArray(role.permissions)
    || !Array.isArray(role.delegablePermissions)) {
    throw new StaffInvitationError('ROLE_NOT_DELEGABLE', 'Choose a role the actor is authorized to delegate in this estate.');
  }
  const allowedPermissions = new Set(role.delegablePermissions);
  if (role.permissions.some((permission) => typeof permission !== 'string'
    || permission.startsWith('platform.') || !allowedPermissions.has(permission))) {
    throw new StaffInvitationError('ROLE_EXCEEDS_DELEGATION', 'The selected role includes permissions the actor cannot delegate.');
  }
  if (!validTime(now) || !validTime(expiresAt)) {
    throw new StaffInvitationError('INVALID_TIMESTAMP', 'Valid invitation and expiry timestamps are required.');
  }
  const createdAt = new Date(now).toISOString();
  const expires = new Date(expiresAt).toISOString();
  if (new Date(expires).getTime() <= new Date(createdAt).getTime()) {
    throw new StaffInvitationError('INVALID_EXPIRY', 'The invitation must expire after it is created.');
  }

  const invitation = Object.freeze({
    id: invitationId,
    estateId,
    inviteeUserId,
    invitedByUserId: actorUserId,
    roleId: role.id,
    roleVersion: role.version ?? null,
    permissionIds: Object.freeze([...role.permissions]),
    status: 'invited',
    createdAt,
    expiresAt: expires,
  });
  return Object.freeze({
    transactionRequired: true,
    invitation,
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId,
      action: 'staff.invitation.created',
      targetType: 'estate_invitation',
      targetId: invitationId,
      outcome: 'success',
      occurredAt: createdAt,
      metadata: Object.freeze({ inviteeUserId, roleId: role.id, expiresAt: expires }),
    }),
  });
}

/** Prepare invite acceptance only when the estate and delegated grant snapshot are still valid. */
function planStaffInvitationAcceptance({ invitation, actorUserId, estate, role, now } = {}) {
  if (!invitation?.id || !invitation.estateId || !invitation.inviteeUserId
    || !actorUserId || String(invitation.inviteeUserId) !== String(actorUserId)) {
    throw new StaffInvitationError('INVITATION_NOT_FOUND', 'The invitation was not found for this account.');
  }
  if (invitation.status !== 'invited') {
    throw new StaffInvitationError('INVITATION_NOT_PENDING', 'Only an invited membership can be accepted.');
  }
  if (!estate?.id || String(estate.id) !== String(invitation.estateId) || estate.status !== 'active') {
    throw new StaffInvitationError('ESTATE_NOT_ACTIVE', 'The invited estate is not active.');
  }
  if (!validTime(now) || !validTime(invitation.expiresAt)) {
    throw new StaffInvitationError('INVALID_TIMESTAMP', 'A valid acceptance and invitation expiry timestamp are required.');
  }
  const acceptedAt = new Date(now).toISOString();
  if (new Date(invitation.expiresAt).getTime() <= new Date(acceptedAt).getTime()) {
    throw new StaffInvitationError('INVITATION_EXPIRED', 'This invitation has expired. Ask an estate administrator to send a new one.');
  }
  if (!role?.id || String(role.id) !== String(invitation.roleId) || role.estateId && role.estateId !== invitation.estateId
    || role.status !== 'active' || !Array.isArray(invitation.permissionIds) || !Array.isArray(role.permissions)) {
    throw new StaffInvitationError('INVITATION_ROLE_UNAVAILABLE', 'The invited estate role is no longer available. Ask an administrator to send a new invitation.');
  }
  const invitedPermissions = new Set(invitation.permissionIds);
  const currentPermissions = new Set(role.permissions);
  if ([...invitedPermissions].some((permission) => typeof permission !== 'string' || permission.startsWith('platform.'))
    || invitedPermissions.size !== currentPermissions.size
    || [...currentPermissions].some((permission) => !invitedPermissions.has(permission))
    || (invitation.roleVersion !== null && invitation.roleVersion !== undefined && role.version !== invitation.roleVersion)) {
    throw new StaffInvitationError('INVITATION_ROLE_CHANGED', 'The invited access has changed. Ask an administrator to send a new invitation.');
  }

  const membership = Object.freeze({
    estateId: invitation.estateId,
    userId: invitation.inviteeUserId,
    invitationId: invitation.id,
    roleId: invitation.roleId,
    status: 'active',
    invitedByUserId: invitation.invitedByUserId,
    activatedAt: acceptedAt,
  });
  return Object.freeze({
    transactionRequired: true,
    invitationId: invitation.id,
    estateId: invitation.estateId,
    acceptedAt,
    membership,
    effects: Object.freeze([
      Object.freeze({ type: 'estate_invitation.accept', invitationId: invitation.id, estateId: invitation.estateId, actorUserId, acceptedAt }),
      Object.freeze({ type: 'estate_membership.activate', estateId: invitation.estateId, userId: invitation.inviteeUserId, roleId: invitation.roleId, invitationId: invitation.id, activatedAt: acceptedAt }),
    ]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: invitation.estateId,
      action: 'staff.invitation.accepted',
      targetType: 'estate_invitation',
      targetId: invitation.id,
      outcome: 'success',
      occurredAt: acceptedAt,
      metadata: Object.freeze({ membershipStatus: 'active', roleId: invitation.roleId }),
    }),
  });
}

module.exports = { StaffInvitationError, planStaffInvitation, planStaffInvitationAcceptance };
