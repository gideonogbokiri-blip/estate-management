class LandlordPropertyDocumentAccessError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'LandlordPropertyDocumentAccessError';
    this.code = code;
  }
}

function validatePrivateAccessGrant(grant, now, maxTtlSeconds, expectedContentType) {
  if (!grant || typeof grant.url !== 'string'
    || typeof grant.expiresAt !== 'string'
    || typeof grant.contentType !== 'string') {
    throw new LandlordPropertyDocumentAccessError(
      'INVALID_FILE_ADAPTER_RESULT',
      'The private file service returned an invalid access grant.',
    );
  }
  let url;
  try {
    url = new URL(grant.url);
  } catch {
    throw new LandlordPropertyDocumentAccessError(
      'INVALID_FILE_ADAPTER_RESULT',
      'The private file service returned an invalid URL.',
    );
  }
  const expiresAt = new Date(grant.expiresAt);
  const lifetimeSeconds =
      (expiresAt.getTime() - new Date(now).getTime()) / 1000;
  if (url.protocol !== 'https:' || !Number.isFinite(lifetimeSeconds)
    || lifetimeSeconds <= 0 || lifetimeSeconds > maxTtlSeconds) {
    throw new LandlordPropertyDocumentAccessError(
      'INVALID_FILE_ADAPTER_RESULT',
      'The private file link must use HTTPS and expire within the configured limit.',
    );
  }
  if (![
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
  ].includes(grant.contentType) || grant.contentType !== expectedContentType) {
    throw new LandlordPropertyDocumentAccessError(
      'INVALID_FILE_ADAPTER_RESULT',
      'The private file service returned an invalid content type.',
    );
  }
  return Object.freeze({
    url: grant.url,
    expiresAt: expiresAt.toISOString(),
    contentType: grant.contentType,
  });
}

/** Resolve a landlord document access ID and obtain a fresh private-file grant. */
function createLandlordPropertyDocumentAccessUseCase({
  transaction,
  resolveAuthorizedLandlordPropertyDocument,
  getLandlordDocumentAccessPolicy,
  createShortLivedPrivateFileAccess,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    resolveAuthorizedLandlordPropertyDocument,
    getLandlordDocumentAccessPolicy,
    createShortLivedPrivateFileAccess,
    appendAuditEvent,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new LandlordPropertyDocumentAccessError(
      'MISSING_ADAPTER',
      `Landlord document access adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new LandlordPropertyDocumentAccessError('INVALID_CLOCK', 'A document access clock is required.');
  }

  return async function accessLandlordPropertyDocument({
    actorUserId,
    estateId,
    documentAccessId,
  } = {}) {
    if (!actorUserId || !estateId || typeof documentAccessId !== 'string'
      || !/^[A-Za-z0-9_-]{16,128}$/.test(documentAccessId)) {
      throw new LandlordPropertyDocumentAccessError(
        'INVALID_INPUT',
        'Authenticated landlord, estate and document access identifier are required.',
      );
    }
    const timestamp = new Date(clock());
    if (Number.isNaN(timestamp.getTime())) {
      throw new LandlordPropertyDocumentAccessError('INVALID_TIMESTAMP', 'A valid document access time is required.');
    }
    const now = timestamp.toISOString();

    return transaction(async (tx) => {
      // Recheck current ownership; a previously listed identifier grants no continuing access.
      const access = await resolveAuthorizedLandlordPropertyDocument(tx, {
        actorUserId,
        estateId,
        documentAccessId,
      });
      if (!access?.document?.id
        || String(access.document.estateId) !== String(estateId)
        || access.document.accessId !== documentAccessId
        || access.document.status !== 'available'
        || !access.property?.id
        || String(access.property.estateId) !== String(estateId)
        || String(access.document.propertyId) !== String(access.property.id)
        || !access.ownership?.id
        || String(access.ownership.estateId) !== String(estateId)
        || String(access.ownership.propertyId) !== String(access.property.id)
        || String(access.ownership.userId) !== String(actorUserId)
        || access.ownership.status !== 'active'
        || access.ownership.verificationStatus !== 'verified'
        || !access.privateFileReference) {
        throw new LandlordPropertyDocumentAccessError(
          'DOCUMENT_NOT_FOUND',
          'The document was not found for this account.',
        );
      }
      const policy = await getLandlordDocumentAccessPolicy(tx, {
        actorUserId,
        estateId,
        property: access.property,
        ownership: access.ownership,
        document: access.document,
      });
      if (!policy || policy.allowed !== true
        || !Number.isInteger(policy.maxTtlSeconds)
        || policy.maxTtlSeconds < 1 || policy.maxTtlSeconds > 300) {
        throw new LandlordPropertyDocumentAccessError(
          'DOCUMENT_ACCESS_DENIED',
          'This document is not available to the current account.',
        );
      }
      const grant = await createShortLivedPrivateFileAccess(tx, {
        actorUserId,
        estateId,
        documentAccessId,
        privateFileReference: access.privateFileReference,
        expiresAt: new Date(
          timestamp.getTime() + policy.maxTtlSeconds * 1000,
        ).toISOString(),
      });
      const safeGrant = validatePrivateAccessGrant(
        grant,
        now,
        policy.maxTtlSeconds,
        access.document.contentType,
      );
      await appendAuditEvent(tx, Object.freeze({
        actorUserId,
        scope: 'estate',
        estateId,
        action: 'landlord_property_document.accessed',
        targetType: 'property_document',
        targetId: access.document.id,
        outcome: 'success',
        occurredAt: now,
        metadata: Object.freeze({ propertyId: access.property.id }),
      }));
      return Object.freeze({
        documentAccessId,
        url: safeGrant.url,
        expiresAt: safeGrant.expiresAt,
        contentType: safeGrant.contentType,
      });
    });
  };
}

module.exports = {
  LandlordPropertyDocumentAccessError,
  createLandlordPropertyDocumentAccessUseCase,
  validatePrivateAccessGrant,
};
