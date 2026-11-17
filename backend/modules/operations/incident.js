const IncidentStatus = Object.freeze({
  REPORTED: 'reported',
  ACKNOWLEDGED: 'acknowledged',
  ASSIGNED: 'assigned',
  INVESTIGATING: 'investigating',
  CONTAINED: 'contained',
  RESOLVED: 'resolved',
  CLOSED: 'closed',
  REOPENED: 'reopened',
});

const IncidentCommand = Object.freeze({
  ACKNOWLEDGE: 'acknowledge',
  ASSIGN: 'assign',
  INVESTIGATE: 'investigate',
  CONTAIN: 'contain',
  RESOLVE: 'resolve',
  CLOSE: 'close',
  REOPEN: 'reopen',
});

class IncidentError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'IncidentError';
    this.code = code;
  }
}

function parseInstant(value) {
  if (value === undefined || value === null || value === '') return null;
  const milliseconds = new Date(value).getTime();
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function prepareIncidentReport(input, context) {
  const {
    estateId,
    reporterUserId,
    category,
    priority,
    description,
    locationDescription,
    observedAt,
    property,
    gate,
    attachmentIds = [],
  } = input ?? {};
  const reportedAtMs = parseInstant(context?.now);
  const observedAtMs = parseInstant(observedAt);
  if (!estateId || estateId !== context?.estateId || !reporterUserId || context.mayReportIncident !== true) {
    throw new IncidentError('PERMISSION_DENIED', 'Incident reporting permission and matching estate context are required.');
  }
  if (!context.categories?.includes(category) || !context.priorities?.includes(priority)) {
    throw new IncidentError('INVALID_CLASSIFICATION', 'Choose an incident category and priority enabled for this estate.');
  }
  if (typeof description !== 'string' || !description.trim()) {
    throw new IncidentError('DESCRIPTION_REQUIRED', 'Provide a description of the incident.');
  }
  if (locationDescription !== undefined && (typeof locationDescription !== 'string'
    || !locationDescription.trim() || locationDescription.trim().length > 120)) {
    throw new IncidentError('INVALID_LOCATION', 'Provide an incident location of no more than 120 characters.');
  }
  if ((property && (!property.id || property.estateId !== estateId))
    || (gate && (!gate.id || gate.estateId !== estateId))) {
    throw new IncidentError('CROSS_ESTATE_LOCATION', 'Incident locations must belong to this estate.');
  }
  if (reportedAtMs === null || observedAtMs === null || observedAtMs > reportedAtMs) {
    throw new IncidentError('INVALID_OBSERVED_TIME', 'Observed time must be valid and cannot be in the future.');
  }
  if (!Array.isArray(attachmentIds) || new Set(attachmentIds).size !== attachmentIds.length
    || attachmentIds.some((id) => !(context.authorizedAttachmentIds ?? []).includes(id))) {
    throw new IncidentError('INVALID_ATTACHMENT', 'Attachments must be authorized private files for this estate.');
  }

  return Object.freeze({
    estateId,
    reporterUserId,
    category,
    priority,
    description: description.trim(),
    locationDescription: typeof locationDescription === 'string' ? locationDescription.trim() : null,
    observedAt: new Date(observedAtMs).toISOString(),
    propertyId: property?.id ?? null,
    gateId: gate?.id ?? null,
    attachmentIds: Object.freeze([...attachmentIds]),
    status: IncidentStatus.REPORTED,
    createdAt: new Date(reportedAtMs).toISOString(),
  });
}

const transitions = Object.freeze({
  [IncidentCommand.ACKNOWLEDGE]: { from: [IncidentStatus.REPORTED, IncidentStatus.REOPENED], to: IncidentStatus.ACKNOWLEDGED },
  [IncidentCommand.ASSIGN]: { from: [IncidentStatus.REPORTED, IncidentStatus.ACKNOWLEDGED, IncidentStatus.REOPENED], to: IncidentStatus.ASSIGNED },
  [IncidentCommand.INVESTIGATE]: { from: [IncidentStatus.ACKNOWLEDGED, IncidentStatus.ASSIGNED, IncidentStatus.CONTAINED], to: IncidentStatus.INVESTIGATING },
  [IncidentCommand.CONTAIN]: { from: [IncidentStatus.INVESTIGATING], to: IncidentStatus.CONTAINED },
  [IncidentCommand.RESOLVE]: { from: [IncidentStatus.INVESTIGATING, IncidentStatus.CONTAINED], to: IncidentStatus.RESOLVED },
  [IncidentCommand.CLOSE]: { from: [IncidentStatus.RESOLVED], to: IncidentStatus.CLOSED },
  [IncidentCommand.REOPEN]: { from: [IncidentStatus.RESOLVED, IncidentStatus.CLOSED], to: IncidentStatus.REOPENED },
});

function planIncidentTransition(incident, input) {
  if (!incident?.id || !incident.estateId) {
    throw new IncidentError('INVALID_INCIDENT', 'A persisted estate incident is required.');
  }
  const { command, actorUserId, now, reason, updateText, mayReopen, assignee } = input ?? {};
  const timestamp = parseInstant(now);
  const transition = transitions[command];
  if (!actorUserId || timestamp === null || !transition || !transition.from.includes(incident.status)) {
    throw new IncidentError('INVALID_TRANSITION', 'This incident cannot make that transition.');
  }
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  const normalizedUpdate = typeof updateText === 'string' ? updateText.trim() : '';
  if ([IncidentCommand.CONTAIN, IncidentCommand.RESOLVE, IncidentCommand.CLOSE, IncidentCommand.REOPEN].includes(command)
    && !(command === IncidentCommand.CONTAIN ? normalizedUpdate : normalizedReason)) {
    throw new IncidentError('REASON_REQUIRED', 'A containment or resolution summary is required for this transition.');
  }
  if (command === IncidentCommand.REOPEN && mayReopen !== true) {
    throw new IncidentError('PERMISSION_DENIED', 'The actor is not permitted to reopen this incident.');
  }
  if (command === IncidentCommand.ASSIGN && (!assignee?.userId
    || assignee.estateId !== incident.estateId || assignee.status !== 'active')) {
    throw new IncidentError('INVALID_ASSIGNEE', 'Assign an active staff member in this estate.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  const effects = [{
    type: 'incident.status_changed',
    incidentId: incident.id,
    estateId: incident.estateId,
    from: incident.status,
    to: transition.to,
    actorUserId,
    reason: normalizedReason || null,
    updateText: normalizedUpdate || null,
    occurredAt,
  }];
  if (command === IncidentCommand.ASSIGN) {
    effects.push({
      type: 'incident.assignment.changed',
      incidentId: incident.id,
      estateId: incident.estateId,
      previousAssigneeUserId: incident.assigneeUserId ?? null,
      assigneeUserId: assignee.userId,
      actorUserId,
      occurredAt,
    });
  }

  return Object.freeze({
    transactionRequired: true,
    incidentId: incident.id,
    estateId: incident.estateId,
    nextStatus: transition.to,
    effects: Object.freeze(effects.map(Object.freeze)),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: incident.estateId,
      action: `incident.${command}`,
      targetType: 'incident',
      targetId: incident.id,
      outcome: 'success',
      reason: normalizedReason || normalizedUpdate || null,
      occurredAt,
    }),
  });
}

function planIncidentUpdate(incident, input) {
  if (!incident?.id || !incident.estateId) {
    throw new IncidentError('INVALID_INCIDENT', 'A persisted estate incident is required.');
  }
  const { actorUserId, now, body, visibility, mayAddInternalNote } = input ?? {};
  const timestamp = parseInstant(now);
  if (!actorUserId || timestamp === null || typeof body !== 'string' || !body.trim()) {
    throw new IncidentError('INVALID_UPDATE', 'An authenticated actor, timestamp and update text are required.');
  }
  if (!['resident_visible', 'internal'].includes(visibility)) {
    throw new IncidentError('INVALID_VISIBILITY', 'Choose resident_visible or internal update visibility.');
  }
  if (visibility === 'internal' && mayAddInternalNote !== true) {
    throw new IncidentError('PERMISSION_DENIED', 'Internal incident notes require the corresponding staff permission.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  return Object.freeze({
    transactionRequired: true,
    incidentId: incident.id,
    estateId: incident.estateId,
    effects: Object.freeze([Object.freeze({
      type: 'incident_update.append',
      incidentId: incident.id,
      estateId: incident.estateId,
      authorUserId: actorUserId,
      visibility,
      body: body.trim(),
      occurredAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: incident.estateId,
      action: `incident.update.${visibility}`,
      targetType: 'incident',
      targetId: incident.id,
      outcome: 'success',
      occurredAt,
    }),
  });
}

module.exports = { IncidentCommand, IncidentError, IncidentStatus, planIncidentTransition, planIncidentUpdate, prepareIncidentReport };
