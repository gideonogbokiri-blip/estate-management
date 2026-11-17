class StaffRoleAssignmentError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'StaffRoleAssignmentError';
    this.code = code;
  }
}

function normalizePermissionIds(permissionIds) {
  if (!Array.isArray(permissionIds) || permissionIds.some((id) => typeof id !== 'string' || !id.trim())) {
    throw new StaffRoleAssignmentError('INVALID_GRANTS', 'Role grants must be a list of permission identifiers.');
  }
  const normalized = permissionIds.map((id) => id.trim());
  if (new Set(normalized).size !== normalized.length) {
    throw new StaffRoleAssignmentError('INVALID_GRANTS', 'Duplicate role grants are not allowed.');
  }
  if (normalized.some((id) => id.startsWith('platform.'))) {
    throw new StaffRoleAssignmentError('PLATFORM_GRANT_FORBIDDEN', 'Estate role assignment cannot include platform permissions.');
  }
  return Object.freeze(normalized.sort());
}

function planStaffRoleAssignment({ membership, actorUserId, role, delegablePermissionIds, reason, now } = {}) {
  if (!membership?.id || !membership.estateId || !membership.userId || !actorUserId) {
    throw new StaffRoleAssignmentError('INVALID_MEMBERSHIP', 'A persisted estate membership and authenticated actor are required.');
  }
  if (String(membership.userId) === String(actorUserId)) {
    throw new StaffRoleAssignmentError('SELF_ASSIGNMENT_FORBIDDEN', 'Members cannot change their own effective estate role.');
  }
  if (membership.status !== 'active' && membership.status !== 'suspended') {
    throw new StaffRoleAssignmentError('INVALID_MEMBERSHIP_STATE', 'Only active or suspended memberships can receive a role change.');
  }
  if (!role?.id || role.status !== 'active' || role.scope !== 'estate') {
    throw new StaffRoleAssignmentError('INVALID_ROLE', 'Choose an active role permitted in this estate.');
  }
  const permissionIds = normalizePermissionIds(role.permissionIds);
  const delegable = new Set(normalizePermissionIds(delegablePermissionIds));
  if (permissionIds.some((permissionId) => !delegable.has(permissionId))) {
    throw new StaffRoleAssignmentError('GRANT_NOT_DELEGABLE', 'The assigning actor cannot delegate every permission in this role.');
  }
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (!normalizedReason || normalizedReason.length > 500) {
    throw new StaffRoleAssignmentError('INVALID_REASON', 'Provide a reason of up to 500 characters.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new StaffRoleAssignmentError('INVALID_TIMESTAMP', 'A valid role assignment timestamp is required.');
  }
  const occurredAt = new Date(now).toISOString();
  const priorRoleId = membership.roleId ?? null;
  const priorPermissionIds = normalizePermissionIds(membership.permissionIds || []);
  const assignment = Object.freeze({
    membershipId: membership.id,
    estateId: membership.estateId,
    userId: membership.userId,
    actorUserId,
    fromRoleId: priorRoleId,
    toRoleId: role.id,
    fromPermissionIds: priorPermissionIds,
    toPermissionIds: permissionIds,
    reason: normalizedReason,
    occurredAt,
  });
  const nextMembership = Object.freeze({
    ...membership,
    roleId: role.id,
    permissionIds,
    roleVersion: role.version ?? null,
    updatedAt: occurredAt,
  });
  return Object.freeze({
    transactionRequired: true,
    assignment,
    nextMembership,
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: membership.estateId,
      action: 'staff.role.assign',
      targetType: 'estate_membership',
      targetId: membership.id,
      outcome: 'success',
      reason: normalizedReason,
      occurredAt,
      metadata: Object.freeze({ fromRoleId: priorRoleId, toRoleId: role.id, userId: membership.userId }),
    }),
  });
}

module.exports = { StaffRoleAssignmentError, planStaffRoleAssignment };
