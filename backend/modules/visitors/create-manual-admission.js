const { createHash, createHmac } = require('node:crypto');
const { planManualAdmission, VisitorPassError } = require('./visitor-pass');

class ManualAdmissionUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ManualAdmissionUseCaseError';
    this.code = code;
  }
}

function sameId(a, b) { return a !== null && a !== undefined && b !== null && b !== undefined && String(a) === String(b); }

function createManualAdmissionUseCase({
  transaction,
  requireManualAdmissionPermission,
  getManualAdmissionPolicy,
  resolveAdmissionProperty,
  generateVisitId,
  createManualAdmissionVisit,
  appendAccessEvent,
  appendAuditEvent,
  readManualAdmissionIdempotency,
  claimManualAdmissionIdempotency,
  completeManualAdmissionIdempotency,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction, requireManualAdmissionPermission, getManualAdmissionPolicy,
    resolveAdmissionProperty, generateVisitId, createManualAdmissionVisit,
    appendAccessEvent, appendAuditEvent, readManualAdmissionIdempotency,
    claimManualAdmissionIdempotency, completeManualAdmissionIdempotency,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new ManualAdmissionUseCaseError('MISSING_ADAPTER', `Manual admission adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new ManualAdmissionUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function createManualAdmission({ actorUserId, estateId, gateId, visitorDisplayName, propertyReference, reason, idempotencyKey } = {}) {
    const name = typeof visitorDisplayName === 'string' ? visitorDisplayName.trim() : '';
    const propertyRef = typeof propertyReference === 'string' ? propertyReference.trim() : '';
    const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
    if (!actorUserId || !estateId || !gateId || !name || name.length > 100
      || !propertyRef || propertyRef.length > 80 || normalizedReason.length < 10 || normalizedReason.length > 500
      || typeof idempotencyKey !== 'string' || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new ManualAdmissionUseCaseError('INVALID_INPUT', 'Visitor name, property reference, a reason of 10 to 500 characters, and a valid request key are required.');
    }
    const idempotencyKeyHash = createHash('sha256').update(`manual-admission:v1:${idempotencyKey}`, 'utf8').digest('hex');
    const payloadHash = createHmac('sha256', idempotencyKey)
      .update(JSON.stringify([name, propertyRef, normalizedReason]), 'utf8').digest('hex');
    const scope = { actorUserId, estateId, gateId, idempotencyKeyHash };
    const replay = (record) => {
      if (!record || !sameId(record.actorUserId, actorUserId) || !sameId(record.estateId, estateId)
        || !sameId(record.gateId, gateId) || record.idempotencyKeyHash !== idempotencyKeyHash
        || record.payloadHash !== payloadHash
        || !record.result || record.result.status !== 'checked_in'
        || !sameId(record.result.estateId, estateId) || !sameId(record.result.gateId, gateId)
        || !record.result.visitId || typeof record.result.visitorName !== 'string'
        || typeof record.result.propertyLabel !== 'string' || !record.result.propertyLabel.trim()) {
        throw new ManualAdmissionUseCaseError('IDEMPOTENCY_KEY_REUSED', 'This manual admission request key is invalid or already in use.');
      }
      return Object.freeze({ ...record.result });
    };
    const firstRead = await transaction(async (tx) => {
      const access = await requireManualAdmissionPermission(tx, { actorUserId, estateId, gateId });
      if (!access || !sameId(access.actorUserId, actorUserId) || !sameId(access.estateId, estateId)
        || !sameId(access.gateId, gateId) || access.allowed !== true
        || !sameId(access.gate?.id, gateId) || !sameId(access.gate?.estateId, estateId)) {
        throw new ManualAdmissionUseCaseError('MANUAL_ADMISSION_DENIED', 'Manual admission is not allowed for this gate assignment.');
      }
      return readManualAdmissionIdempotency(tx, scope);
    });
    if (firstRead) return replay(firstRead);

    return transaction(async (tx) => {
      const access = await requireManualAdmissionPermission(tx, { actorUserId, estateId, gateId });
      const gate = access?.gate;
      if (!access || !sameId(access.actorUserId, actorUserId) || !sameId(access.estateId, estateId)
        || !sameId(access.gateId, gateId) || access.allowed !== true
        || !sameId(gate?.id, gateId) || !sameId(gate?.estateId, estateId)) {
        throw new ManualAdmissionUseCaseError('MANUAL_ADMISSION_DENIED', 'Manual admission is not allowed for this gate assignment.');
      }
      const prior = await readManualAdmissionIdempotency(tx, scope);
      if (prior) return replay(prior);
      const policy = await getManualAdmissionPolicy(tx, { actorUserId, estateId, gateId, gateContext: access });
      if (!policy || policy.enabled !== true) {
        throw new ManualAdmissionUseCaseError('MANUAL_ADMISSION_DISABLED', 'Manual admission is disabled by estate policy.');
      }
      const property = await resolveAdmissionProperty(tx, { estateId, gateContext: access, propertyReference: propertyRef });
      if (!property?.id || !sameId(property.estateId, estateId)) {
        throw new ManualAdmissionUseCaseError('PROPERTY_NOT_AVAILABLE', 'Choose a property in this estate for the admission record.');
      }
      const visitId = await generateVisitId(tx, { estateId, gateId });
      if (!visitId) throw new ManualAdmissionUseCaseError('INVALID_VISIT_ID', 'A gate visit reference could not be generated.');
      const now = clock();
      const nowDate = new Date(now);
      if (Number.isNaN(nowDate.getTime())) throw new ManualAdmissionUseCaseError('INVALID_CLOCK', 'The gate admission clock is invalid.');
      let plan;
      try {
        plan = planManualAdmission({
          estateId, property, gate, staffUserId: actorUserId, visitId,
          visitorDisplayName: name, reason: normalizedReason, now,
        });
      } catch (error) {
        if (error instanceof VisitorPassError) throw new ManualAdmissionUseCaseError(error.code, error.message);
        throw error;
      }
      const claim = await claimManualAdmissionIdempotency(tx, { ...scope, payloadHash });
      if (claim?.state === 'completed') return replay(claim.record);
      if (!claim || claim.state !== 'claimed' || !claim.id
        || !sameId(claim.actorUserId, actorUserId) || !sameId(claim.estateId, estateId)
        || !sameId(claim.gateId, gateId) || claim.idempotencyKeyHash !== idempotencyKeyHash
        || claim.payloadHash !== payloadHash) {
        throw new ManualAdmissionUseCaseError('INVALID_IDEMPOTENCY_RESULT', 'The manual admission request key could not be claimed safely.');
      }
      const visitEffect = plan.effects.find((effect) => effect.type === 'visitor_visit.checked_in');
      const eventEffect = plan.effects.find((effect) => effect.type === 'access_event.append');
      if (!visitEffect || !eventEffect || !sameId(visitEffect.visitId, visitId)
        || !sameId(eventEffect.visitId, visitId) || visitEffect.admissionType !== 'manual'
        || visitEffect.passId !== null || eventEffect.eventKind !== 'manual_admission') {
        throw new ManualAdmissionUseCaseError('INVALID_PLAN', 'The manual admission plan is incomplete.');
      }
      const visit = await createManualAdmissionVisit(tx, { effect: visitEffect });
      if (!visit || !sameId(visit.id, visitId) || !sameId(visit.estateId, estateId)
        || !sameId(visit.gateId, gateId) || !sameId(visit.propertyId, property.id)
        || visit.passId !== null || visit.admissionType !== 'manual' || visit.status !== 'checked_in'
        || visit.checkedInAt !== visitEffect.checkedInAt || !sameId(visit.checkedInByUserId, actorUserId)
        || visit.visitorDisplayName !== name) {
        throw new ManualAdmissionUseCaseError('INVALID_COMMIT_RESULT', 'The manual admission visit was not committed as planned.');
      }
      await appendAccessEvent(tx, eventEffect);
      await appendAuditEvent(tx, plan.auditEvent);
      const result = Object.freeze({
        visitId, estateId, gateId, status: 'checked_in', visitorName: name,
        hostDisplayName: 'Manual admission', propertyLabel: property.displayLabel,
        vehicleSummary: null, checkedInAt: visitEffect.checkedInAt,
      });
      if (typeof result.propertyLabel !== 'string' || !result.propertyLabel.trim() || result.propertyLabel.length > 160) {
        throw new ManualAdmissionUseCaseError('INVALID_PROPERTY_PROJECTION', 'The authorized property label is invalid.');
      }
      const completed = await completeManualAdmissionIdempotency(tx, { claim, payloadHash, result });
      if (!completed || !sameId(completed.id, claim.id) || completed.state !== 'completed'
        || !sameId(completed.actorUserId, actorUserId) || !sameId(completed.estateId, estateId)
        || !sameId(completed.gateId, gateId) || completed.idempotencyKeyHash !== idempotencyKeyHash
        || completed.payloadHash !== payloadHash
        || !sameId(completed.result?.visitId, visitId)) {
        throw new ManualAdmissionUseCaseError('INVALID_IDEMPOTENCY_RESULT', 'The manual admission result could not be saved for safe retry.');
      }
      return result;
    });
  };
}

module.exports = { ManualAdmissionUseCaseError, createManualAdmissionUseCase };
