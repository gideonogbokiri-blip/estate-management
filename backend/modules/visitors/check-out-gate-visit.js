const { planPassCheckOut } = require('./visitor-pass');

class GateVisitCheckOutError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'GateVisitCheckOutError';
    this.code = code;
  }
}

function createGateVisitCheckOutUseCase({
  transaction,
  resolveAssignedGateAccess,
  findActiveVisitForUpdate,
  commitVisitCheckOut,
  appendAccessEvent,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveAssignedGateAccess, findActiveVisitForUpdate, commitVisitCheckOut, appendAccessEvent, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new GateVisitCheckOutError('MISSING_ADAPTER', `Gate check-out adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new GateVisitCheckOutError('INVALID_CLOCK', 'A clock function is required.');

  return async function checkOutGateVisit({ actorUserId, estateId, gateId, visitId } = {}) {
    if (!actorUserId || !estateId || !gateId || !visitId) {
      throw new GateVisitCheckOutError('INVALID_INPUT', 'Authenticated gate staff, gate and active visit are required.');
    }
    return transaction(async (tx) => {
      const gateContext = await resolveAssignedGateAccess(tx, { actorUserId, estateId, gateId });
      const gate = gateContext?.gate;
      if (!gateContext || String(gateContext.actorUserId) !== String(actorUserId)
        || String(gateContext.estateId) !== String(estateId) || String(gateContext.gateId) !== String(gateId)
        || gateContext.allowed !== true || !gate?.id || String(gate.id) !== String(gateId)
        || String(gate.estateId) !== String(estateId)) {
        throw new GateVisitCheckOutError('GATE_ACCESS_DENIED', 'The staff member is not assigned to this gate.');
      }
      const visit = await findActiveVisitForUpdate(tx, { estateId, gateId, visitId, gateContext });
      if (!visit || String(visit.id) !== String(visitId) || String(visit.estateId) !== String(estateId)
        || String(visit.gateId) !== String(gateId) || visit.status !== 'checked_in') {
        throw new GateVisitCheckOutError('ACTIVE_VISIT_NOT_FOUND', 'No active visit was found for this gate.');
      }
      const now = clock();
      const plan = planPassCheckOut({ activeVisit: visit, gate, staffUserId: actorUserId, now });
      const visitEffect = plan.effects.find((effect) => effect.type === 'visitor_visit.checked_out');
      const accessEffect = plan.effects.find((effect) => effect.type === 'access_event.append');
      if (!visitEffect || !accessEffect) throw new GateVisitCheckOutError('INVALID_PLAN', 'The check-out plan is incomplete.');
      const updatedVisit = await commitVisitCheckOut(tx, { visit, effect: visitEffect });
      if (!updatedVisit || String(updatedVisit.id) !== String(visitId)
        || String(updatedVisit.estateId) !== String(estateId) || String(updatedVisit.gateId) !== String(gateId)
        || updatedVisit.status !== 'checked_out' || updatedVisit.checkedOutAt !== visitEffect.checkedOutAt
        || String(updatedVisit.checkedOutByUserId) !== String(actorUserId)) {
        throw new GateVisitCheckOutError('INVALID_COMMIT_RESULT', 'The repository did not confirm the gate visit check-out.');
      }
      await appendAccessEvent(tx, accessEffect);
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ visitId, estateId, gateId, status: 'checked_out', checkedOutAt: visitEffect.checkedOutAt });
    });
  };
}

module.exports = { GateVisitCheckOutError, createGateVisitCheckOutUseCase };
