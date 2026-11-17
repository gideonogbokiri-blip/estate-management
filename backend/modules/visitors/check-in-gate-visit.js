const { createHash } = require('node:crypto');
const { hashVisitorCredential, planPassCheckIn, VisitorPassError } = require('./visitor-pass');

class GateVisitCheckInError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'GateVisitCheckInError';
    this.code = code;
  }
}

function sameId(a, b) { return a !== null && a !== undefined && b !== null && b !== undefined && String(a) === String(b); }

function createGateVisitCheckInUseCase({
  transaction,
  resolveAssignedGateAccess,
  enforceVerificationRateLimit,
  findPassForVerificationUpdate,
  readCheckInIdempotency,
  claimCheckInIdempotency,
  completeCheckInIdempotency,
  findActiveVisitForPass,
  consumePassUse,
  createCheckedInVisit,
  appendAccessEvent,
  appendAuditEvent,
  generateVisitId,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction, resolveAssignedGateAccess, enforceVerificationRateLimit,
    findPassForVerificationUpdate, readCheckInIdempotency, claimCheckInIdempotency,
    completeCheckInIdempotency, findActiveVisitForPass, consumePassUse,
    createCheckedInVisit, appendAccessEvent, appendAuditEvent, generateVisitId,
  };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new GateVisitCheckInError('MISSING_ADAPTER', `Gate check-in adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new GateVisitCheckInError('INVALID_CLOCK', 'A clock function is required.');

  return async function checkInGateVisit({ actorUserId, estateId, gateId, credential, idempotencyKey, requestContext } = {}) {
    if (!actorUserId || !estateId || !gateId || typeof credential !== 'string' || !requestContext
      || typeof idempotencyKey !== 'string' || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new GateVisitCheckInError('INVALID_INPUT', 'Authenticated gate staff, gate, credential, idempotency key and trusted request context are required.');
    }
    if (credential.length > 256) throw new GateVisitCheckInError('INVALID_INPUT', 'The visitor credential is invalid.');

    const initialGateContext = await transaction(async (tx) =>
      resolveAssignedGateAccess(tx, { actorUserId, estateId, gateId }),
    );
    const initialGate = initialGateContext?.gate;
    if (!initialGateContext || !sameId(initialGateContext.actorUserId, actorUserId)
      || !sameId(initialGateContext.estateId, estateId) || !sameId(initialGateContext.gateId, gateId)
      || initialGateContext.allowed !== true || !sameId(initialGate?.id, gateId) || !sameId(initialGate?.estateId, estateId)) {
      throw new GateVisitCheckInError('GATE_ACCESS_DENIED', 'The staff member is not assigned to this gate.');
    }

    const credentialHash = hashVisitorCredential(credential);
    const idempotencyKeyHash = createHash('sha256').update(`gate-check-in:v1:${idempotencyKey}`, 'utf8').digest('hex');
    const credentialFingerprint = createHash('sha256')
      .update(`visitor-gate-attempt:v1:${credential.slice(0, 256)}`, 'utf8').digest('hex');
    const idempotencyScope = { actorUserId, estateId, gateId, idempotencyKeyHash };
    const replay = (record) => {
      if (!record || !sameId(record.actorUserId, actorUserId) || !sameId(record.estateId, estateId)
        || !sameId(record.gateId, gateId) || record.idempotencyKeyHash !== idempotencyKeyHash
        || !credentialHash || record.credentialHash !== credentialHash
        || !record.result || record.result.status !== 'checked_in'
        || !sameId(record.result.estateId, estateId) || !sameId(record.result.gateId, gateId)) {
        throw new GateVisitCheckInError('IDEMPOTENCY_KEY_REUSED', 'This check-in request key was already used for a different request.');
      }
      if (!record.result.visitId || typeof record.result.visitorName !== 'string' || !record.result.visitorName.trim()
        || typeof record.result.propertyLabel !== 'string' || !record.result.propertyLabel.trim()
        || typeof record.result.hostDisplayName !== 'string' || !record.result.hostDisplayName.trim()
        || !Number.isFinite(Date.parse(record.result.checkedInAt)) || !Number.isFinite(Date.parse(record.result.validUntil))) {
        throw new GateVisitCheckInError('INVALID_IDEMPOTENCY_RESULT', 'The saved check-in result is invalid.');
      }
      return Object.freeze({ ...record.result });
    };
    const previous = await transaction(async (tx) => {
      const gateContext = await resolveAssignedGateAccess(tx, { actorUserId, estateId, gateId });
      if (!gateContext || !sameId(gateContext.actorUserId, actorUserId)
        || !sameId(gateContext.estateId, estateId) || !sameId(gateContext.gateId, gateId)
        || gateContext.allowed !== true || !sameId(gateContext.gate?.id, gateId)
        || !sameId(gateContext.gate?.estateId, estateId)) {
        throw new GateVisitCheckInError('GATE_ACCESS_DENIED', 'The staff member is not assigned to this gate.');
      }
      return readCheckInIdempotency(tx, idempotencyScope);
    });
    if (previous) return replay(previous);

    const rateLimit = await enforceVerificationRateLimit({
      actorUserId, estateId, gateId, credentialFingerprint, requestContext,
    });
    if (rateLimit !== true) throw new GateVisitCheckInError('RATE_LIMITED', 'Too many verification attempts. Please wait and try again.');

    const outcome = await transaction(async (tx) => {
      const gateContext = await resolveAssignedGateAccess(tx, { actorUserId, estateId, gateId });
      const gate = gateContext?.gate;
      if (!gateContext || !sameId(gateContext.actorUserId, actorUserId)
        || !sameId(gateContext.estateId, estateId) || !sameId(gateContext.gateId, gateId)
        || gateContext.allowed !== true || !sameId(gate?.id, gateId) || !sameId(gate?.estateId, estateId)) {
        throw new GateVisitCheckInError('GATE_ACCESS_DENIED', 'The staff member is not assigned to this gate.');
      }
      const requestRecord = await readCheckInIdempotency(tx, idempotencyScope);
      if (requestRecord) return replay(requestRecord);
      const now = clock();
      const nowDate = new Date(now);
      if (Number.isNaN(nowDate.getTime())) throw new GateVisitCheckInError('INVALID_CLOCK', 'The gate check-in clock returned an invalid time.');
      const occurredAt = nowDate.toISOString();
      const deny = async () => {
        await appendAccessEvent(tx, {
          estateId, gateId, staffUserId: actorUserId, eventKind: 'denied',
          reasonCode: 'invalid_credential', occurredAt,
        });
        await appendAuditEvent(tx, {
          actorUserId, scope: 'gate', estateId, gateId, action: 'visitor_pass.verify_denied',
          targetType: 'gate', targetId: gateId, outcome: 'denied', reasonCode: 'invalid_credential', occurredAt,
        });
        return Object.freeze({ denied: true });
      };

      if (!credentialHash) return deny();
      const pass = await findPassForVerificationUpdate(tx, { estateId, credentialHash, gateContext });
      if (!pass) return deny();
      if (!sameId(pass.estateId, estateId) || !pass.id || pass.credentialHash !== credentialHash) {
        throw new GateVisitCheckInError('INVALID_REPOSITORY_RESULT', 'The visitor pass lookup returned an invalid result.');
      }
      const previous = await readCheckInIdempotency(tx, idempotencyScope);
      if (previous) return replay(previous);
      const activeVisit = await findActiveVisitForPass(tx, { estateId, passId: pass.id, gateContext });
      if (activeVisit && (!sameId(activeVisit.estateId, estateId) || !sameId(activeVisit.passId, pass.id)
        || activeVisit.status !== 'checked_in')) {
        throw new GateVisitCheckInError('INVALID_REPOSITORY_RESULT', 'The active visit lookup returned an invalid result.');
      }
      const visitId = await generateVisitId(tx, { estateId, gateId });
      if (!visitId) throw new GateVisitCheckInError('INVALID_VISIT_ID', 'A gate visit reference could not be generated.');

      let plan;
      try {
        plan = planPassCheckIn({ pass, credential, gate, staffUserId: actorUserId, visitId, now, activeVisit });
      } catch (error) {
        if (error instanceof VisitorPassError && error.code === 'INVALID_CREDENTIAL') return deny();
        throw error;
      }
      const idempotencyClaim = await claimCheckInIdempotency(tx, {
        ...idempotencyScope, credentialHash,
      });
      if (idempotencyClaim?.state === 'completed') return replay(idempotencyClaim.record);
      if (!idempotencyClaim || idempotencyClaim.state !== 'claimed' || !idempotencyClaim.id
        || !sameId(idempotencyClaim.actorUserId, actorUserId) || !sameId(idempotencyClaim.estateId, estateId)
        || !sameId(idempotencyClaim.gateId, gateId) || idempotencyClaim.idempotencyKeyHash !== idempotencyKeyHash
        || idempotencyClaim.credentialHash !== credentialHash) {
        throw new GateVisitCheckInError('INVALID_IDEMPOTENCY_RESULT', 'The check-in request key could not be claimed safely.');
      }
      const useEffect = plan.effects.find((effect) => effect.type === 'visitor_pass.use_consumed');
      const visitEffect = plan.effects.find((effect) => effect.type === 'visitor_visit.checked_in');
      const accessEffect = plan.effects.find((effect) => effect.type === 'access_event.append');
      if (!useEffect || !visitEffect || !accessEffect
        || !sameId(useEffect.passId, pass.id) || !sameId(visitEffect.passId, pass.id)
        || !sameId(visitEffect.visitId, visitId) || !sameId(accessEffect.visitId, visitId)) {
        throw new GateVisitCheckInError('INVALID_PLAN', 'The gate check-in plan is incomplete.');
      }
      if (typeof visitEffect.visitorName !== 'string' || !visitEffect.visitorName.trim() || visitEffect.visitorName.length > 100
        || typeof visitEffect.propertyLabel !== 'string' || !visitEffect.propertyLabel.trim() || visitEffect.propertyLabel.length > 160
        || typeof visitEffect.hostDisplayName !== 'string' || !visitEffect.hostDisplayName.trim() || visitEffect.hostDisplayName.length > 160
        || !(visitEffect.vehicleSummary === null || (typeof visitEffect.vehicleSummary === 'string' && visitEffect.vehicleSummary.length <= 80))) {
        throw new GateVisitCheckInError('INVALID_PASS_PROJECTION', 'The visitor pass is missing authorized gate display details.');
      }
      const updatedPass = await consumePassUse(tx, { pass, effect: useEffect });
      if (!updatedPass || !sameId(updatedPass.id, pass.id) || !sameId(updatedPass.estateId, estateId)
        || updatedPass.useCount !== useEffect.newUseCount) {
        throw new GateVisitCheckInError('INVALID_COMMIT_RESULT', 'The visitor pass use was not committed as planned.');
      }
      const visit = await createCheckedInVisit(tx, { effect: visitEffect });
      if (!visit || !sameId(visit.id, visitId) || !sameId(visit.estateId, estateId)
        || !sameId(visit.passId, pass.id) || !sameId(visit.gateId, gateId)
        || visit.status !== 'checked_in' || visit.checkedInAt !== visitEffect.checkedInAt
        || !sameId(visit.checkedInByUserId, actorUserId)) {
        throw new GateVisitCheckInError('INVALID_COMMIT_RESULT', 'The gate visit was not committed as planned.');
      }
      await appendAccessEvent(tx, accessEffect);
      await appendAuditEvent(tx, plan.auditEvent);
      const result = Object.freeze({
        visitId, estateId, gateId, status: 'checked_in',
        visitorName: visitEffect.visitorName, propertyLabel: visitEffect.propertyLabel,
        hostDisplayName: visitEffect.hostDisplayName, vehicleSummary: visitEffect.vehicleSummary,
        checkedInAt: visitEffect.checkedInAt, validUntil: plan.verification.visit.validUntil,
      });
      const completedRequest = await completeCheckInIdempotency(tx, { claim: idempotencyClaim, credentialHash, result });
      if (!completedRequest || !sameId(completedRequest.id, idempotencyClaim.id)
        || completedRequest.state !== 'completed' || !sameId(completedRequest.actorUserId, actorUserId)
        || !sameId(completedRequest.estateId, estateId) || !sameId(completedRequest.gateId, gateId)
        || completedRequest.idempotencyKeyHash !== idempotencyKeyHash
        || completedRequest.credentialHash !== credentialHash || !sameId(completedRequest.result?.visitId, visitId)) {
        throw new GateVisitCheckInError('INVALID_IDEMPOTENCY_RESULT', 'The check-in request could not be saved for safe retry.');
      }
      return result;
    });

    if (outcome.denied) throw new GateVisitCheckInError('INVALID_CREDENTIAL', 'This credential cannot be admitted.');
    return outcome;
  };
}

module.exports = { GateVisitCheckInError, createGateVisitCheckInUseCase };
