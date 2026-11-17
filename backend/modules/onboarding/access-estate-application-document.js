class EstateApplicationDocumentAccessError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationDocumentAccessError';
    this.code = code;
  }
}

function validatePrivateAccessGrant(grant, now, maxTtlSeconds) {
  if (!grant || typeof grant.url !== 'string' || typeof grant.expiresAt !== 'string'
    || typeof grant.contentType !== 'string') {
    throw new EstateApplicationDocumentAccessError('INVALID_FILE_ADAPTER_RESULT', 'The private file service returned an invalid access grant.');
  }
  let url;
  try { url = new URL(grant.url); } catch {
    throw new EstateApplicationDocumentAccessError('INVALID_FILE_ADAPTER_RESULT', 'The private file service returned an invalid URL.');
  }
  const expiresAt = new Date(grant.expiresAt);
  const lifetimeSeconds = (expiresAt.getTime() - new Date(now).getTime()) / 1000;
  if (url.protocol !== 'https:' || !Number.isFinite(lifetimeSeconds) || lifetimeSeconds <= 0 || lifetimeSeconds > maxTtlSeconds) {
    throw new EstateApplicationDocumentAccessError('INVALID_FILE_ADAPTER_RESULT', 'The private file link must use HTTPS and expire within the configured limit.');
  }
  if (!/^[a-z0-9!#$&^_.+-]+\/[a-z0-9!#$&^_.+-]+$/i.test(grant.contentType)) {
    throw new EstateApplicationDocumentAccessError('INVALID_FILE_ADAPTER_RESULT', 'The private file service returned an invalid content type.');
  }
  return Object.freeze({ url: grant.url, expiresAt: expiresAt.toISOString(), contentType: grant.contentType });
}

/** Authorize access to one application document through Zvend's existing private-file service. */
function createEstateApplicationDocumentAccessUseCase({
  transaction,
  resolveAuthorizedApplicationDocument,
  getDocumentAccessPolicy,
  createShortLivedPrivateFileAccess,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveAuthorizedApplicationDocument, getDocumentAccessPolicy, createShortLivedPrivateFileAccess, appendAuditEvent };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new EstateApplicationDocumentAccessError('MISSING_ADAPTER', `Application document access adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new EstateApplicationDocumentAccessError('INVALID_CLOCK', 'A clock function is required.');

  return async function accessEstateApplicationDocument({ actorUserId, applicationId, documentAccessId } = {}) {
    if (!actorUserId || !applicationId || !documentAccessId) {
      throw new EstateApplicationDocumentAccessError('INVALID_INPUT', 'Authenticated actor, application and document access identifier are required.');
    }
    const timestamp = new Date(clock());
    if (Number.isNaN(timestamp.getTime())) throw new EstateApplicationDocumentAccessError('INVALID_TIMESTAMP', 'A valid document access timestamp is required.');
    const now = timestamp.toISOString();

    return transaction(async (tx) => {
      const access = await resolveAuthorizedApplicationDocument(tx, { actorUserId, applicationId, documentAccessId });
      if (!access?.application?.id || String(access.application.id) !== String(applicationId)
        || !access.document?.id || access.document.accessId !== documentAccessId
        || String(access.document.applicationId) !== String(applicationId)
        || !['applicant', 'assigned_reviewer', 'platform_reviewer'].includes(access.accessScope)
        || !access.privateFileReference) {
        throw new EstateApplicationDocumentAccessError('DOCUMENT_NOT_FOUND', 'The document was not found for this account.');
      }
      const policy = await getDocumentAccessPolicy(tx, { actorUserId, accessScope: access.accessScope, application: access.application, document: access.document });
      if (!policy || policy.allowed !== true || !Number.isInteger(policy.maxTtlSeconds)
        || policy.maxTtlSeconds < 1 || policy.maxTtlSeconds > 300) {
        throw new EstateApplicationDocumentAccessError('DOCUMENT_ACCESS_DENIED', 'This document is not available to the current account.');
      }
      const grant = await createShortLivedPrivateFileAccess(tx, {
        actorUserId,
        applicationId,
        documentAccessId,
        privateFileReference: access.privateFileReference,
        expiresAt: new Date(timestamp.getTime() + policy.maxTtlSeconds * 1000).toISOString(),
      });
      const safeGrant = validatePrivateAccessGrant(grant, now, policy.maxTtlSeconds);
      await appendAuditEvent(tx, Object.freeze({
        actorUserId,
        scope: 'platform',
        action: 'estate_application.document_accessed',
        targetType: 'estate_application_document',
        targetId: access.document.id,
        outcome: 'success',
        occurredAt: now,
        metadata: Object.freeze({ applicationId, accessScope: access.accessScope }),
      }));
      return Object.freeze({
        applicationId,
        documentAccessId,
        url: safeGrant.url,
        expiresAt: safeGrant.expiresAt,
        contentType: safeGrant.contentType,
      });
    });
  };
}

module.exports = { EstateApplicationDocumentAccessError, createEstateApplicationDocumentAccessUseCase, validatePrivateAccessGrant };
