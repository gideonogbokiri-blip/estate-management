const { createHash, randomBytes, timingSafeEqual } = require('node:crypto');

class VisitorPassError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'VisitorPassError';
    this.code = code;
  }
}

function parseInstant(value) {
  if (value === undefined || value === null || value === '') return null;
  const milliseconds = new Date(value).getTime();
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function createVisitorCredential() {
  const credential = randomBytes(32).toString('base64url');
  const credentialHash = hashVisitorCredential(credential);
  return Object.freeze({ credential, credentialHash });
}

function hashVisitorCredential(credential) {
  if (typeof credential !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(credential)) return null;
  return createHash('sha256').update(credential, 'utf8').digest('hex');
}

function credentialMatches(credential, storedHash) {
  if (typeof credential !== 'string' || !/^[a-f0-9]{64}$/i.test(storedHash ?? '')) return false;
  const candidate = hashVisitorCredential(credential);
  if (!candidate) return false;
  const candidateHash = Buffer.from(candidate, 'hex');
  const expectedHash = Buffer.from(storedHash, 'hex');
  return timingSafeEqual(candidateHash, expectedHash);
}

/** Prepare a pass record and one-time secret. The caller verifies the host/property link. */
function prepareVisitorPass(input, policy, now) {
  const {
    estateId,
    property,
    hostUserId,
    visitorDisplayName,
    validFrom,
    validUntil,
    allowedUses,
    vehicleSummary,
  } = input ?? {};
  const currentTime = parseInstant(now);
  const fromTime = parseInstant(validFrom);
  const untilTime = parseInstant(validUntil);

  if (!estateId || !property?.id || property.estateId !== estateId || !hostUserId) {
    throw new VisitorPassError('INVALID_VISIT_SCOPE', 'Estate, authorized property, and host are required.');
  }
  if (typeof input?.hostMayUseProperty !== 'boolean' || !input.hostMayUseProperty) {
    throw new VisitorPassError('HOST_NOT_AUTHORIZED', 'The host is not authorized to create a pass for this property.');
  }
  if (typeof visitorDisplayName !== 'string' || !visitorDisplayName.trim() || visitorDisplayName.trim().length > 100) {
    throw new VisitorPassError('VISITOR_NAME_REQUIRED', 'A visitor display name of at most 100 characters is required.');
  }
  if (currentTime === null || fromTime === null || untilTime === null || fromTime < currentTime || untilTime <= fromTime) {
    throw new VisitorPassError('INVALID_VALIDITY_WINDOW', 'Choose a valid future visit window.');
  }
  if (!Number.isInteger(allowedUses) || allowedUses < 1
    || !Number.isInteger(policy?.maximumUses) || policy.maximumUses < 1
    || allowedUses > policy.maximumUses) {
    throw new VisitorPassError('INVALID_USE_LIMIT', 'The pass use limit exceeds estate policy.');
  }
  if (!Number.isFinite(policy?.maximumDurationMs) || policy.maximumDurationMs <= 0
    || untilTime - fromTime > policy.maximumDurationMs) {
    throw new VisitorPassError('INVALID_VALIDITY_WINDOW', 'The visit window exceeds estate policy.');
  }
  if (vehicleSummary !== undefined && vehicleSummary !== null
    && (!policy.collectVehicleDetails || typeof vehicleSummary !== 'string' || vehicleSummary.trim().length > 80)) {
    throw new VisitorPassError('VEHICLE_DETAILS_NOT_ALLOWED', 'Vehicle details are not enabled by estate policy.');
  }

  const { credential, credentialHash } = createVisitorCredential();
  const record = Object.freeze({
    estateId,
    propertyId: property.id,
    hostUserId,
    visitorDisplayName: visitorDisplayName.trim(),
    credentialHash,
    validFrom: new Date(fromTime).toISOString(),
    validUntil: new Date(untilTime).toISOString(),
    allowedUses,
    useCount: 0,
    revokedAt: null,
    createdAt: new Date(currentTime).toISOString(),
    vehicleSummary: policy.collectVehicleDetails && typeof vehicleSummary === 'string'
      ? vehicleSummary.trim() || null
      : null,
  });

  return Object.freeze({ record, credential });
}

function planPassVerification({ pass, credential, gate, now, activeVisit }) {
  const currentTime = parseInstant(now);
  const fromTime = parseInstant(pass?.validFrom);
  const untilTime = parseInstant(pass?.validUntil);
  const unavailable = () => new VisitorPassError('INVALID_CREDENTIAL', 'This credential cannot be verified.');

  if (!pass?.id || !gate?.id || String(gate.estateId) !== String(pass.estateId)
    || !credentialMatches(credential, pass.credentialHash)
    || currentTime === null || fromTime === null || untilTime === null
    || pass.revokedAt || currentTime < fromTime || currentTime >= untilTime
    || !Number.isInteger(pass.allowedUses) || !Number.isInteger(pass.useCount)
    || pass.useCount >= pass.allowedUses
    || (activeVisit?.passId !== undefined && String(activeVisit.passId) === String(pass.id))) {
    throw unavailable();
  }

  return Object.freeze({
    valid: true,
    nextAction: 'check_in',
    visit: Object.freeze({
      passId: pass.id,
      visitorName: pass.visitorDisplayName,
      propertyLabel: pass.propertyLabel,
      hostDisplayName: pass.hostDisplayName,
      validUntil: new Date(untilTime).toISOString(),
      vehicleSummary: pass.vehicleSummary ?? null,
    }),
  });
}

function planPassCheckIn({ pass, credential, gate, staffUserId, visitId, now, activeVisit }) {
  if (!staffUserId) {
    throw new VisitorPassError('MISSING_ACTOR', 'The authenticated gate staff member is required.');
  }
  if (!visitId) throw new VisitorPassError('MISSING_VISIT_ID', 'A gate visit reference is required.');
  const verification = planPassVerification({ pass, credential, gate, now, activeVisit });
  const checkedInAt = new Date(now).toISOString();

  return Object.freeze({
    transactionRequired: true,
    passId: pass.id,
    estateId: pass.estateId,
    gateId: gate.id,
    effects: Object.freeze([
      Object.freeze({ type: 'visitor_pass.use_consumed', passId: pass.id, expectedUseCount: pass.useCount, newUseCount: pass.useCount + 1 }),
      Object.freeze({
        type: 'visitor_visit.checked_in',
        visitId,
        passId: pass.id,
        estateId: pass.estateId,
        propertyId: pass.propertyId,
        gateId: gate.id,
        visitorName: verification.visit.visitorName,
        propertyLabel: verification.visit.propertyLabel,
        hostDisplayName: verification.visit.hostDisplayName,
        vehicleSummary: verification.visit.vehicleSummary,
        checkedInByUserId: staffUserId,
        checkedInAt,
        status: 'checked_in',
      }),
      Object.freeze({
        type: 'access_event.append',
        visitId,
        estateId: pass.estateId,
        passId: pass.id,
        propertyId: pass.propertyId,
        gateId: gate.id,
        staffUserId,
        eventKind: 'entry',
        occurredAt: checkedInAt,
      }),
    ]),
    verification,
    auditEvent: Object.freeze({
      actorUserId: staffUserId,
      scope: 'gate',
      estateId: pass.estateId,
      gateId: gate.id,
      action: 'visitor_pass.check_in',
      targetType: 'visitor_pass',
      targetId: pass.id,
      outcome: 'success',
      occurredAt: checkedInAt,
    }),
  });
}

function planPassCheckOut({ activeVisit, gate, staffUserId, now }) {
  const checkedOutAt = parseInstant(now);
  const manualAdmission = activeVisit?.admissionType === 'manual' && !activeVisit?.passId;
  if (!activeVisit?.id || (!activeVisit.passId && !manualAdmission) || !activeVisit.estateId || !activeVisit.propertyId
    || !gate?.id || String(gate.estateId) !== String(activeVisit.estateId) || String(activeVisit.gateId) !== String(gate.id)) {
    throw new VisitorPassError('ACTIVE_VISIT_NOT_FOUND', 'No active visit was found for this gate.');
  }
  if (!staffUserId || checkedOutAt === null) {
    throw new VisitorPassError('INVALID_CHECK_OUT', 'Gate staff and a valid check-out time are required.');
  }

  const timestamp = new Date(checkedOutAt).toISOString();
  return Object.freeze({
    transactionRequired: true,
    visitId: activeVisit.id,
    effects: Object.freeze([
      Object.freeze({
        type: 'visitor_visit.checked_out',
        visitId: activeVisit.id,
        expectedStatus: 'checked_in',
        checkedOutByUserId: staffUserId,
        checkedOutAt: timestamp,
      }),
      Object.freeze({
        type: 'access_event.append',
        estateId: activeVisit.estateId,
        passId: activeVisit.passId ?? null,
        propertyId: activeVisit.propertyId,
        gateId: gate.id,
        staffUserId,
        eventKind: 'exit',
        admissionType: manualAdmission ? 'manual' : undefined,
        occurredAt: timestamp,
      }),
    ]),
    auditEvent: Object.freeze({
      actorUserId: staffUserId,
      scope: 'gate',
      estateId: activeVisit.estateId,
      gateId: gate.id,
      action: 'visitor_pass.check_out',
      targetType: 'visitor_visit',
      targetId: activeVisit.id,
      outcome: 'success',
      occurredAt: timestamp,
    }),
  });
}

function planPassRevocation(pass, { actorUserId, now, reason } = {}) {
  const timestamp = parseInstant(now);
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (!pass?.id || !pass.estateId || !actorUserId || timestamp === null || !normalizedReason) {
    throw new VisitorPassError('INVALID_REVOCATION', 'Pass, actor, timestamp, and revocation reason are required.');
  }
  if (pass.revokedAt) {
    throw new VisitorPassError('ALREADY_REVOKED', 'The pass is already revoked.');
  }

  const revokedAt = new Date(timestamp).toISOString();
  return Object.freeze({
    transactionRequired: true,
    passId: pass.id,
    estateId: pass.estateId,
    effects: Object.freeze([Object.freeze({
      type: 'visitor_pass.revoked',
      passId: pass.id,
      estateId: pass.estateId,
      revokedByUserId: actorUserId,
      revokedAt,
      reason: normalizedReason,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: pass.estateId,
      action: 'visitor_pass.revoke',
      targetType: 'visitor_pass',
      targetId: pass.id,
      outcome: 'success',
      reason: normalizedReason,
      occurredAt: revokedAt,
    }),
  });
}

function planManualAdmission({ estateId, property, gate, staffUserId, visitId, visitorDisplayName, reason, now }) {
  const timestamp = parseInstant(now);
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (!estateId || !property?.id || String(property.estateId) !== String(estateId)
    || !gate?.id || String(gate.estateId) !== String(estateId) || !staffUserId || !visitId || timestamp === null
    || !normalizedReason || normalizedReason.length > 500 || typeof visitorDisplayName !== 'string'
    || !visitorDisplayName.trim() || visitorDisplayName.trim().length > 100) {
    throw new VisitorPassError('INVALID_MANUAL_ADMISSION', 'Same-estate property and gate, staff, time, and a reason are required.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  return Object.freeze({
    transactionRequired: true,
    visitId,
    estateId,
    gateId: gate.id,
    effects: Object.freeze([
      Object.freeze({
        type: 'visitor_visit.checked_in', visitId, estateId, passId: null,
        admissionType: 'manual', propertyId: property.id, gateId: gate.id,
        visitorName: visitorDisplayName.trim(), checkedInByUserId: staffUserId,
        checkedInAt: occurredAt, status: 'checked_in',
      }),
      Object.freeze({
        type: 'access_event.append', visitId, estateId, passId: null,
        propertyId: property.id, gateId: gate.id, staffUserId,
        eventKind: 'manual_admission', reason: normalizedReason, occurredAt,
      }),
    ]),
    auditEvent: Object.freeze({
      actorUserId: staffUserId,
      scope: 'gate',
      estateId,
      gateId: gate.id,
      action: 'visitor.manual_admission',
      targetType: 'visitor_visit',
      targetId: visitId,
      outcome: 'success',
      reason: normalizedReason,
      occurredAt,
    }),
  });
}

module.exports = {
  VisitorPassError,
  createVisitorCredential,
  credentialMatches,
  hashVisitorCredential,
  planManualAdmission,
  planPassCheckIn,
  planPassCheckOut,
  planPassRevocation,
  planPassVerification,
  prepareVisitorPass,
};
