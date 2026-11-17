const { prepareIncidentReport } = require('./incident');

class IncidentReportCreationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'IncidentReportCreationError';
    this.code = code;
  }
}

function createIncidentReportUseCase({
  transaction,
  resolveIncidentReporterAccess,
  getIncidentPolicy,
  verifyPrivateAttachments,
  generateIncidentId,
  createIncidentRecord,
  appendAuditEvent,
  enqueueIncidentNotice,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveIncidentReporterAccess, getIncidentPolicy, verifyPrivateAttachments,
    generateIncidentId, createIncidentRecord, appendAuditEvent, enqueueIncidentNotice };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new IncidentReportCreationError('MISSING_ADAPTER', `Incident report adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new IncidentReportCreationError('INVALID_CLOCK', 'A clock function is required.');

  return async function createIncidentReport({
    actorUserId, estateId, category, priority, description, locationDescription, observedAt, attachmentIds = [],
  } = {}) {
    if (!actorUserId || !estateId || typeof description !== 'string' || description.trim().length > 1000) {
      throw new IncidentReportCreationError('INVALID_REPORT_INPUT', 'Authenticated reporter, estate and an incident description of up to 1000 characters are required.');
    }
    return transaction(async (tx) => {
      const access = await resolveIncidentReporterAccess(tx, { actorUserId, estateId });
      if (!access || access.userId !== actorUserId || access.estateId !== estateId || access.mayReportIncident !== true) {
        throw new IncidentReportCreationError('REPORT_ACCESS_DENIED', 'The actor cannot report incidents in this estate.');
      }
      const policy = await getIncidentPolicy(tx, { estateId, access });
      if (!policy || !Array.isArray(policy.categories) || !Array.isArray(policy.priorities)) {
        throw new IncidentReportCreationError('INCIDENT_POLICY_REQUIRED', 'Load the estate incident policy before accepting reports.');
      }
      if (!Array.isArray(attachmentIds) || attachmentIds.length > 5
        || new Set(attachmentIds).size !== attachmentIds.length) {
        throw new IncidentReportCreationError('INVALID_ATTACHMENTS', 'Provide up to five unique private attachment references.');
      }
      const authorized = await verifyPrivateAttachments(tx, { actorUserId, estateId, attachmentIds });
      if (!authorized || !Array.isArray(authorized.authorizedAttachmentIds)
        || attachmentIds.some((id) => !authorized.authorizedAttachmentIds.includes(id))) {
        throw new IncidentReportCreationError('INVALID_ATTACHMENTS', 'Every attachment must be authorized private evidence for this incident.');
      }
      const incidentId = await generateIncidentId(tx, { estateId });
      if (!incidentId) throw new IncidentReportCreationError('INVALID_INCIDENT_ID', 'An incident reference could not be generated.');
      const now = clock();
      const incident = prepareIncidentReport({
        estateId, reporterUserId: actorUserId, category, priority, description, locationDescription,
        observedAt, property: access.property ?? null, gate: access.gate ?? null, attachmentIds,
      }, {
        estateId, now, mayReportIncident: true,
        categories: policy.categories, priorities: policy.priorities,
        authorizedAttachmentIds: authorized.authorizedAttachmentIds,
      });
      const record = Object.freeze({ id: incidentId, ...incident });
      const created = await createIncidentRecord(tx, record);
      if (!created || String(created.id) !== String(incidentId) || created.estateId !== estateId
        || created.reporterUserId !== actorUserId || created.status !== 'reported') {
        throw new IncidentReportCreationError('INVALID_CREATE_RESULT', 'The repository did not persist the incident report in this estate.');
      }
      await appendAuditEvent(tx, {
        actorUserId, scope: access.gate ? 'gate' : 'estate', estateId,
        gateId: access.gate?.id ?? null, action: 'incident.report',
        targetType: 'incident', targetId: incidentId, outcome: 'success', occurredAt: record.createdAt,
      });
      await enqueueIncidentNotice(tx, { estateId, incidentId, category, priority });
      return Object.freeze({ incidentId, estateId, category, priority, status: 'reported',
        locationDescription: record.locationDescription, observedAt: record.observedAt, createdAt: record.createdAt });
    });
  };
}

module.exports = { IncidentReportCreationError, createIncidentReportUseCase };
