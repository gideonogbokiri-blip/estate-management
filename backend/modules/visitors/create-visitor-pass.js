const { prepareVisitorPass } = require('./visitor-pass');
const { createHash, createHmac } = require('node:crypto');

class VisitorPassCreationUseCaseError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'VisitorPassCreationUseCaseError';
    this.code = code;
  }
}

function createVisitorPassUseCase({
  transaction,
  resolveHostPropertyAccess,
  findPropertyForUpdate,
  getVisitorPassPolicy,
  generatePassId,
  createPassRecord,
  appendAuditEvent,
  enqueueHostNotice,
  readVisitorPassCreationIdempotency,
  claimVisitorPassCreationIdempotency,
  completeVisitorPassCreationIdempotency,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveHostPropertyAccess, findPropertyForUpdate, getVisitorPassPolicy,
    generatePassId, createPassRecord, appendAuditEvent, enqueueHostNotice,
    readVisitorPassCreationIdempotency, claimVisitorPassCreationIdempotency, completeVisitorPassCreationIdempotency };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) {
    throw new VisitorPassCreationUseCaseError('MISSING_ADAPTER', `Visitor pass adapters are required: ${missing.join(', ')}.`);
  }
  if (typeof clock !== 'function') throw new VisitorPassCreationUseCaseError('INVALID_CLOCK', 'A clock function is required.');

  return async function createVisitorPass({
    actorUserId, estateId, propertyId, visitorDisplayName, validFrom, validUntil, vehicleSummary = null, idempotencyKey,
  } = {}) {
    if (!actorUserId || !estateId) {
      throw new VisitorPassCreationUseCaseError('INVALID_CREATION_INPUT', 'Authenticated host and estate context are required.');
    }
    if (typeof visitorDisplayName !== 'string' || visitorDisplayName.trim().length > 100) {
      throw new VisitorPassCreationUseCaseError('INVALID_VISITOR_NAME', 'Provide a visitor name of no more than 100 characters.');
    }
    if (vehicleSummary !== null && (typeof vehicleSummary !== 'string' || vehicleSummary.trim().length > 80)) {
      throw new VisitorPassCreationUseCaseError('INVALID_VEHICLE_SUMMARY', 'Vehicle details must be no more than 80 characters.');
    }
    if (typeof idempotencyKey !== 'string' || !/^[A-Za-z0-9._~-]{24,128}$/.test(idempotencyKey)) {
      throw new VisitorPassCreationUseCaseError('INVALID_IDEMPOTENCY_KEY', 'A valid visitor-pass request key is required.');
    }
    const normalizedName = visitorDisplayName.trim();
    const normalizedVehicle = typeof vehicleSummary === 'string' ? vehicleSummary.trim() || null : null;
    const validFromTime = new Date(validFrom).getTime();
    const validUntilTime = new Date(validUntil).getTime();
    if (!Number.isFinite(validFromTime) || !Number.isFinite(validUntilTime)) {
      throw new VisitorPassCreationUseCaseError('INVALID_VALIDITY_WINDOW', 'Choose a valid visitor pass window.');
    }
    const normalizedFrom = new Date(validFromTime).toISOString();
    const normalizedUntil = new Date(validUntilTime).toISOString();
    const idempotencyKeyHash = createHash('sha256').update(`visitor-pass-create:v1:${idempotencyKey}`, 'utf8').digest('hex');
    const scope = { actorUserId, estateId, idempotencyKeyHash };

    return transaction(async (tx) => {
      const access = await resolveHostPropertyAccess(tx, { actorUserId, estateId, propertyId: propertyId ?? null });
      const authorizedPropertyId = propertyId ?? access?.propertyId;
      if (!access || access.userId !== actorUserId || access.estateId !== estateId || !authorizedPropertyId
        || (Array.isArray(access.propertyIds)
          ? !access.propertyIds.some((id) => String(id) === String(authorizedPropertyId))
          : access.propertyId != null && String(access.propertyId) !== String(authorizedPropertyId))
        || access.active !== true || access.mayCreateVisitorPass !== true) {
        throw new VisitorPassCreationUseCaseError('HOST_ACCESS_DENIED', 'The host cannot create a visitor pass for this property.');
      }
      const property = await findPropertyForUpdate(tx, { estateId, propertyId: authorizedPropertyId });
      if (!property || property.estateId !== estateId || String(property.id) !== String(authorizedPropertyId)
        || property.status === 'archived') {
        throw new VisitorPassCreationUseCaseError('PROPERTY_NOT_FOUND', 'The property was not found in this estate.');
      }
      const payloadHash = createHmac('sha256', idempotencyKey)
        .update(JSON.stringify([String(property.id), normalizedName, normalizedFrom, normalizedUntil, normalizedVehicle]), 'utf8')
        .digest('hex');
      const rejectReplay = (record) => {
        if (!record || String(record.actorUserId) !== String(actorUserId) || String(record.estateId) !== String(estateId)
          || record.idempotencyKeyHash !== idempotencyKeyHash || record.payloadHash !== payloadHash
          || record.state !== 'completed' || !record.passId) {
          throw new VisitorPassCreationUseCaseError('IDEMPOTENCY_KEY_REUSED', 'This request key is already in use with different or incomplete details.');
        }
        throw new VisitorPassCreationUseCaseError('VISITOR_PASS_ALREADY_CREATED', 'This visitor pass was already created for this request. Credentials are shown only once; check the pass list before issuing another.');
      };
      const prior = await readVisitorPassCreationIdempotency(tx, scope);
      if (prior) rejectReplay(prior);
      const policy = await getVisitorPassPolicy(tx, { estateId, property, access });
      if (!policy || !Number.isInteger(policy.maximumUses) || policy.maximumUses < 1
        || !Number.isFinite(policy.maximumDurationMs) || policy.maximumDurationMs <= 0) {
        throw new VisitorPassCreationUseCaseError('VISITOR_POLICY_REQUIRED', 'Load a valid visitor pass policy before creating a pass.');
      }
      const id = await generatePassId(tx, { estateId });
      if (!id) throw new VisitorPassCreationUseCaseError('INVALID_PASS_ID', 'A visitor pass reference could not be generated.');
      const claim = await claimVisitorPassCreationIdempotency(tx, { ...scope, payloadHash });
      if (claim?.state === 'completed') rejectReplay(claim.record);
      if (!claim || claim.state !== 'claimed' || !claim.id
        || String(claim.actorUserId) !== String(actorUserId) || String(claim.estateId) !== String(estateId)
        || claim.idempotencyKeyHash !== idempotencyKeyHash || claim.payloadHash !== payloadHash) {
        throw new VisitorPassCreationUseCaseError('IDEMPOTENCY_CLAIM_FAILED', 'The visitor pass request could not be claimed safely.');
      }
      const createdAt = clock();
      const prepared = prepareVisitorPass({
        estateId, property, hostUserId: actorUserId, hostMayUseProperty: true,
        visitorDisplayName: normalizedName, validFrom: normalizedFrom, validUntil: normalizedUntil,
        allowedUses: 1, vehicleSummary,
      }, policy, createdAt);
      const record = Object.freeze({ id, ...prepared.record });
      const created = await createPassRecord(tx, record);
      if (!created || String(created.id) !== String(id) || created.estateId !== estateId
        || String(created.propertyId) !== String(authorizedPropertyId) || created.hostUserId !== actorUserId
        || created.credentialHash !== prepared.record.credentialHash) {
        throw new VisitorPassCreationUseCaseError('INVALID_CREATE_RESULT', 'The repository did not persist the planned visitor pass.');
      }
      const occurredAt = new Date(createdAt).toISOString();
      await appendAuditEvent(tx, {
        actorUserId, scope: 'estate', estateId, action: 'visitor_pass.create',
        targetType: 'visitor_pass', targetId: id, outcome: 'success', occurredAt,
      });
      // The notification adapter receives no credential or credential hash.
      await enqueueHostNotice(tx, { estateId, passId: id, hostUserId: actorUserId });
      const completed = await completeVisitorPassCreationIdempotency(tx, {
        claim, payloadHash, passId: id,
      });
      if (!completed || String(completed.id) !== String(claim.id) || completed.state !== 'completed'
        || String(completed.actorUserId) !== String(actorUserId) || String(completed.estateId) !== String(estateId)
        || completed.idempotencyKeyHash !== idempotencyKeyHash || completed.payloadHash !== payloadHash
        || String(completed.passId) !== String(id)) {
        throw new VisitorPassCreationUseCaseError('IDEMPOTENCY_COMPLETION_FAILED', 'The visitor pass request could not be committed for safe retry.');
      }
      return Object.freeze({
        passId: id, estateId, propertyId: authorizedPropertyId,
        visitorDisplayName: record.visitorDisplayName, validFrom: record.validFrom,
        validUntil: record.validUntil, allowedUses: record.allowedUses,
        vehicleSummary: record.vehicleSummary, credential: prepared.credential,
      });
    });
  };
}

module.exports = { VisitorPassCreationUseCaseError, createVisitorPassUseCase };
