class CurrentGateVisitorsError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'CurrentGateVisitorsError';
    this.code = code;
  }
}

const projectionFields = new Set([
  'visitId', 'passId', 'hostUserId', 'propertyId', 'hostDisplayName', 'propertyLabel', 'checkedInAt',
]);

function safeCurrentVisitor(visit, pass, projection, gateContext) {
  const validId = (value) => ['string', 'number'].includes(typeof value) && String(value).trim() !== ''
    && (typeof value !== 'number' || Number.isFinite(value));
  const sameId = (a, b) => String(a ?? '') === String(b ?? '');
  if (!validId(visit?.id) || !validId(visit?.passId) || !validId(visit?.gateId)
    || !validId(pass?.id) || !validId(pass?.hostUserId) || !validId(pass?.propertyId)
    || !sameId(visit.estateId, gateContext.estateId) || !sameId(visit.gateId, gateContext.gateId)
    || !sameId(visit.passId, pass.id) || !sameId(pass.estateId, gateContext.estateId)
    || visit.status !== 'checked_in') {
    throw new CurrentGateVisitorsError('INVALID_VISIT', 'The current visit is outside the assigned gate or pass scope.');
  }
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !projectionFields.has(field))
    || !sameId(projection.visitId, visit.id) || !sameId(projection.passId, pass.id)
    || !sameId(projection.hostUserId, pass.hostUserId) || !sameId(projection.propertyId, pass.propertyId)
    || projection.checkedInAt !== visit.checkedInAt) {
    throw new CurrentGateVisitorsError('INVALID_PROJECTION', 'Gate visitor display values must match the active visit and authorized pass.');
  }
  const boundedText = (value, field, limit, optional = false) => {
    if (optional && (value === null || value === undefined || value === '')) return null;
    if (typeof value !== 'string' || !value.trim() || value.length > limit) {
      throw new CurrentGateVisitorsError('INVALID_PROJECTION', `${field} must be bounded display text.`);
    }
    return value.trim();
  };
  if (typeof visit.checkedInAt !== 'string' || Number.isNaN(Date.parse(visit.checkedInAt))
    || new Date(visit.checkedInAt).toISOString() !== visit.checkedInAt) {
    throw new CurrentGateVisitorsError('INVALID_VISIT', 'The check-in timestamp is invalid.');
  }
  return Object.freeze({
    visitId: visit.id,
    visitorName: boundedText(pass.visitorDisplayName, 'Visitor name', 100),
    hostDisplayName: boundedText(projection.hostDisplayName, 'Host display name', 160),
    propertyLabel: boundedText(projection.propertyLabel, 'Property label', 160),
    vehicleSummary: boundedText(pass.vehicleSummary, 'Vehicle summary', 80, true),
    checkedInAt: visit.checkedInAt,
  });
}

function safeManualCurrentVisitor(visit, projection, gateContext) {
  const fields = new Set(['visitId', 'estateId', 'gateId', 'propertyId', 'visitorName', 'propertyLabel', 'checkedInAt']);
  const sameId = (a, b) => String(a ?? '') === String(b ?? '');
  const validId = (value) => ['string', 'number'].includes(typeof value) && String(value).trim() !== ''
    && (typeof value !== 'number' || Number.isFinite(value));
  if (!validId(visit?.id) || !validId(visit?.estateId) || !validId(visit?.gateId) || !validId(visit?.propertyId)
    || !validId(gateContext?.estateId) || !validId(gateContext?.gateId)
    || visit.passId !== null || visit.admissionType !== 'manual'
    || !sameId(visit.estateId, gateContext.estateId) || !sameId(visit.gateId, gateContext.gateId)
    || visit.status !== 'checked_in'
    || typeof visit.visitorDisplayName !== 'string' || !visit.visitorDisplayName.trim() || visit.visitorDisplayName.length > 100
    || typeof visit.checkedInAt !== 'string' || Number.isNaN(Date.parse(visit.checkedInAt))
    || new Date(visit.checkedInAt).toISOString() !== visit.checkedInAt) {
    throw new CurrentGateVisitorsError('INVALID_MANUAL_VISIT', 'The manual admission is outside the assigned gate scope.');
  }
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !fields.has(field))
    || !sameId(projection.visitId, visit.id) || !sameId(projection.estateId, visit.estateId)
    || !sameId(projection.gateId, visit.gateId) || !sameId(projection.propertyId, visit.propertyId)
    || projection.visitorName !== visit.visitorDisplayName || projection.checkedInAt !== visit.checkedInAt) {
    throw new CurrentGateVisitorsError('INVALID_MANUAL_PROJECTION', 'Manual admission display values must match the active visit.');
  }
  if (typeof projection.propertyLabel !== 'string' || !projection.propertyLabel.trim() || projection.propertyLabel.length > 160) {
    throw new CurrentGateVisitorsError('INVALID_MANUAL_PROJECTION', 'The manual admission property label is invalid.');
  }
  return Object.freeze({
    visitId: visit.id,
    visitorName: visit.visitorDisplayName.trim(),
    hostDisplayName: 'Manual admission',
    propertyLabel: projection.propertyLabel.trim(),
    vehicleSummary: null,
    checkedInAt: visit.checkedInAt,
  });
}

function createCurrentGateVisitorsUseCase({
  transaction,
  resolveAssignedGateAccess,
  queryCurrentGateVisits,
  loadPassForGateVisit,
  projectCurrentGateVisitor,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveAssignedGateAccess, queryCurrentGateVisits, loadPassForGateVisit, projectCurrentGateVisitor };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new CurrentGateVisitorsError('MISSING_ADAPTER', `Gate visitor adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new CurrentGateVisitorsError('INVALID_CLOCK', 'A clock function is required.');

  return async function listCurrentGateVisitors({ actorUserId, estateId, gateId } = {}) {
    if (!actorUserId || !estateId || !gateId) {
      throw new CurrentGateVisitorsError('INVALID_INPUT', 'Authenticated gate staff and assigned gate context are required.');
    }
    return transaction(async (tx) => {
      const gateContext = await resolveAssignedGateAccess(tx, { actorUserId, estateId, gateId });
      if (!gateContext || String(gateContext.actorUserId) !== String(actorUserId)
        || String(gateContext.estateId) !== String(estateId)
        || String(gateContext.gateId) !== String(gateId) || gateContext.allowed !== true) {
        throw new CurrentGateVisitorsError('GATE_ACCESS_DENIED', 'The staff member is not assigned to this gate.');
      }
      const visits = await queryCurrentGateVisits(tx, { gateContext, limit: 100 });
      if (!Array.isArray(visits) || visits.length > 100) {
        throw new CurrentGateVisitorsError('INVALID_REPOSITORY_RESULT', 'The gate query must return at most 100 active visits.');
      }
      const visitIds = new Set();
      const activePassIds = new Set();
      const items = [];
      for (const visit of visits) {
        if (!visit?.id || visitIds.has(String(visit.id))) {
          throw new CurrentGateVisitorsError('DUPLICATE_VISIT', 'The gate query returned an invalid or duplicate visit.');
        }
        visitIds.add(String(visit.id));
        if (visit.passId === null && visit.admissionType === 'manual') {
          const projection = await projectCurrentGateVisitor({ actorUserId, gateContext, visit, pass: null, tx });
          items.push(safeManualCurrentVisitor(visit, projection, gateContext));
          continue;
        }
        if (!visit.passId || activePassIds.has(String(visit.passId))) {
          throw new CurrentGateVisitorsError('DUPLICATE_ACTIVE_PASS', 'A visitor pass cannot have multiple active visits at this gate.');
        }
        activePassIds.add(String(visit.passId));
        const pass = await loadPassForGateVisit(tx, { gateContext, visit });
        const projection = await projectCurrentGateVisitor({ actorUserId, gateContext, visit, pass, tx });
        items.push(safeCurrentVisitor(visit, pass, projection, gateContext));
      }
      const asOf = new Date(clock());
      if (Number.isNaN(asOf.getTime())) throw new CurrentGateVisitorsError('INVALID_CLOCK', 'The gate visitor service clock is invalid.');
      return Object.freeze({ estateId, gateId, items: Object.freeze(items), asOf: asOf.toISOString() });
    });
  };
}

module.exports = { CurrentGateVisitorsError, createCurrentGateVisitorsUseCase, safeCurrentVisitor };
