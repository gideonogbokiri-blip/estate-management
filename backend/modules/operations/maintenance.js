const MaintenanceStatus = Object.freeze({
  SUBMITTED: 'submitted',
  UNDER_REVIEW: 'under_review',
  ASSIGNED: 'assigned',
  IN_PROGRESS: 'in_progress',
  AWAITING_PARTS: 'awaiting_parts',
  RESOLVED: 'resolved',
  CLOSED: 'closed',
  REJECTED: 'rejected',
  REOPENED: 'reopened',
});

const MaintenanceCommand = Object.freeze({
  REVIEW: 'review',
  ASSIGN: 'assign',
  START: 'start',
  AWAIT_PARTS: 'await_parts',
  RESUME: 'resume',
  RESOLVE: 'resolve',
  CLOSE: 'close',
  REJECT: 'reject',
  REOPEN: 'reopen',
});

class MaintenanceError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'MaintenanceError';
    this.code = code;
  }
}

const transitions = Object.freeze({
  [MaintenanceCommand.REVIEW]: { from: [MaintenanceStatus.SUBMITTED], to: MaintenanceStatus.UNDER_REVIEW },
  [MaintenanceCommand.ASSIGN]: { from: [MaintenanceStatus.UNDER_REVIEW, MaintenanceStatus.REOPENED], to: MaintenanceStatus.ASSIGNED },
  [MaintenanceCommand.START]: { from: [MaintenanceStatus.ASSIGNED], to: MaintenanceStatus.IN_PROGRESS },
  [MaintenanceCommand.AWAIT_PARTS]: { from: [MaintenanceStatus.IN_PROGRESS], to: MaintenanceStatus.AWAITING_PARTS },
  [MaintenanceCommand.RESUME]: { from: [MaintenanceStatus.AWAITING_PARTS], to: MaintenanceStatus.IN_PROGRESS },
  [MaintenanceCommand.RESOLVE]: { from: [MaintenanceStatus.IN_PROGRESS], to: MaintenanceStatus.RESOLVED },
  [MaintenanceCommand.CLOSE]: { from: [MaintenanceStatus.RESOLVED], to: MaintenanceStatus.CLOSED },
  [MaintenanceCommand.REJECT]: { from: [MaintenanceStatus.SUBMITTED, MaintenanceStatus.UNDER_REVIEW], to: MaintenanceStatus.REJECTED },
  [MaintenanceCommand.REOPEN]: { from: [MaintenanceStatus.RESOLVED, MaintenanceStatus.CLOSED], to: MaintenanceStatus.REOPENED },
});

function validInstant(value) {
  if (value === undefined || value === null || value === '') return null;
  const milliseconds = new Date(value).getTime();
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function planMaintenanceTransition(request, input) {
  if (!request?.id || !request.estateId || !request.propertyId) {
    throw new MaintenanceError('INVALID_REQUEST', 'A persisted estate maintenance request is required.');
  }
  const { command, actorUserId, now, reason, resolutionSummary, assignee, mayReopen } = input ?? {};
  const timestamp = validInstant(now);
  const transition = transitions[command];
  if (!actorUserId || timestamp === null) {
    throw new MaintenanceError('INVALID_ACTOR_OR_TIME', 'An authenticated actor and valid timestamp are required.');
  }
  if (!transition || !transition.from.includes(request.status)) {
    throw new MaintenanceError('INVALID_TRANSITION', 'This maintenance request cannot make that transition.');
  }

  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  const normalizedResolution = typeof resolutionSummary === 'string' ? resolutionSummary.trim() : '';
  if ([MaintenanceCommand.REJECT, MaintenanceCommand.CLOSE, MaintenanceCommand.REOPEN].includes(command) && !normalizedReason) {
    throw new MaintenanceError('REASON_REQUIRED', 'A reason is required for this transition.');
  }
  if (command === MaintenanceCommand.RESOLVE && !normalizedResolution) {
    throw new MaintenanceError('RESOLUTION_REQUIRED', 'A resident-visible resolution summary is required.');
  }
  if (command === MaintenanceCommand.ASSIGN && (!assignee?.userId
    || assignee.estateId !== request.estateId || assignee.status !== 'active')) {
    throw new MaintenanceError('INVALID_ASSIGNEE', 'Assign an active staff member or contractor in this estate.');
  }
  if (command === MaintenanceCommand.START && !request.assigneeUserId) {
    throw new MaintenanceError('ASSIGNMENT_REQUIRED', 'Assign the request before work can start.');
  }
  if (command === MaintenanceCommand.REOPEN && mayReopen !== true) {
    throw new MaintenanceError('PERMISSION_DENIED', 'The actor is not permitted to reopen this request.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  const effects = [{
    type: 'maintenance_request.status_changed',
    requestId: request.id,
    estateId: request.estateId,
    from: request.status,
    to: transition.to,
    actorUserId,
    reason: normalizedReason || null,
    resolutionSummary: normalizedResolution || null,
    occurredAt,
  }];
  if (command === MaintenanceCommand.ASSIGN) {
    effects.push({
      type: 'maintenance_assignment.changed',
      requestId: request.id,
      estateId: request.estateId,
      previousAssigneeUserId: request.assigneeUserId ?? null,
      assigneeUserId: assignee.userId,
      actorUserId,
      occurredAt,
    });
  }

  return Object.freeze({
    transactionRequired: true,
    requestId: request.id,
    estateId: request.estateId,
    nextStatus: transition.to,
    effects: Object.freeze(effects.map(Object.freeze)),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: request.estateId,
      action: `maintenance.${command}`,
      targetType: 'maintenance_request',
      targetId: request.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt,
    }),
  });
}

function planMaintenanceAssignment(request, input) {
  if (!request?.id || !request.estateId || !request.propertyId) {
    throw new MaintenanceError('INVALID_REQUEST', 'A persisted estate maintenance request is required.');
  }
  const { actorUserId, assignee, now, reason } = input ?? {};
  const timestamp = validInstant(now);
  if (!actorUserId || timestamp === null || !assignee?.userId
    || assignee.estateId !== request.estateId || assignee.status !== 'active') {
    throw new MaintenanceError('INVALID_ASSIGNEE', 'Assign an active staff member or contractor in this estate.');
  }
  if (![MaintenanceStatus.UNDER_REVIEW, MaintenanceStatus.ASSIGNED, MaintenanceStatus.REOPENED].includes(request.status)) {
    throw new MaintenanceError('INVALID_ASSIGNMENT_STATE', 'This request cannot be assigned in its current state.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  return Object.freeze({
    transactionRequired: true,
    requestId: request.id,
    estateId: request.estateId,
    effects: Object.freeze([Object.freeze({
      type: 'maintenance_assignment.changed',
      requestId: request.id,
      estateId: request.estateId,
      previousAssigneeUserId: request.assigneeUserId ?? null,
      assigneeUserId: assignee.userId,
      actorUserId,
      reason: normalizedReason || null,
      occurredAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: request.estateId,
      action: 'maintenance.assign',
      targetType: 'maintenance_request',
      targetId: request.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt,
    }),
  });
}

function planMaintenanceUpdate(request, input) {
  if (!request?.id || !request.estateId || !request.propertyId) {
    throw new MaintenanceError('INVALID_REQUEST', 'A persisted estate maintenance request is required.');
  }
  const { actorUserId, now, body, visibility, mayAddInternalNote } = input ?? {};
  const timestamp = validInstant(now);
  if (!actorUserId || timestamp === null || typeof body !== 'string' || !body.trim()) {
    throw new MaintenanceError('INVALID_UPDATE', 'An authenticated actor, timestamp, and update text are required.');
  }
  if (!['resident_visible', 'internal'].includes(visibility)) {
    throw new MaintenanceError('INVALID_VISIBILITY', 'Choose resident_visible or internal update visibility.');
  }
  if (visibility === 'internal' && mayAddInternalNote !== true) {
    throw new MaintenanceError('PERMISSION_DENIED', 'Internal notes require the corresponding staff permission.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  return Object.freeze({
    transactionRequired: true,
    requestId: request.id,
    estateId: request.estateId,
    effects: Object.freeze([Object.freeze({
      type: 'maintenance_update.append',
      requestId: request.id,
      estateId: request.estateId,
      authorUserId: actorUserId,
      visibility,
      body: body.trim(),
      occurredAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: request.estateId,
      action: `maintenance.update.${visibility}`,
      targetType: 'maintenance_request',
      targetId: request.id,
      outcome: 'success',
      occurredAt,
    }),
  });
}

module.exports = {
  MaintenanceCommand,
  MaintenanceError,
  MaintenanceStatus,
  planMaintenanceAssignment,
  planMaintenanceTransition,
  planMaintenanceUpdate,
};
