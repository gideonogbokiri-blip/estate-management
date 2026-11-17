class LandlordPropertyDocumentListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'LandlordPropertyDocumentListError';
    this.code = code;
  }
}

const documentCategories = new Set([
  'ownership', 'tenancy_agreement', 'inspection', 'maintenance', 'insurance', 'other',
]);
const contentTypes = new Set([
  'application/pdf', 'image/jpeg', 'image/png', 'image/webp',
]);
const accessIdPattern = /^[A-Za-z0-9_-]{16,128}$/;

function safeLabel(value, field, limit) {
  if (typeof value !== 'string' || !value.trim() || value.length > limit) {
    throw new LandlordPropertyDocumentListError('INVALID_PROJECTION', `${field} must be bounded display text.`);
  }
  return value.trim();
}

function projectLandlordPropertyDocument(row, actorUserId, estateId) {
  const property = row?.property;
  const ownership = row?.ownership;
  const document = row?.document;
  const projection = row?.projection;
  if (!property?.id || String(property.estateId) !== String(estateId)
    || !ownership?.id || String(ownership.estateId) !== String(estateId)
    || String(ownership.propertyId) !== String(property.id)
    || String(ownership.userId) !== String(actorUserId)
    || ownership.status !== 'active' || ownership.verificationStatus !== 'verified'
    || !document?.id || String(document.estateId) !== String(estateId)
    || String(document.propertyId) !== String(property.id)
    || document.status !== 'available') {
    throw new LandlordPropertyDocumentListError(
      'RELATIONSHIP_SCOPE_VIOLATION',
      'The document is outside the landlord’s active verified property relationship.',
    );
  }
  if (!projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((key) => ![
      'documentAccessId', 'propertyLabel', 'documentName', 'category', 'contentType', 'updatedAt',
    ].includes(key))
    || String(projection.documentAccessId ?? '').length < 16
    || String(projection.documentAccessId).length > 128
    || !accessIdPattern.test(projection.documentAccessId)) {
    throw new LandlordPropertyDocumentListError(
      'INVALID_PROJECTION',
      'The document projection must contain only safe labels and a non-sensitive access identifier.',
    );
  }
  if (!documentCategories.has(projection.category)
    || !contentTypes.has(projection.contentType)) {
    throw new LandlordPropertyDocumentListError(
      'INVALID_DOCUMENT_METADATA',
      'Document category or content type is unsupported.',
    );
  }
  if (document.updatedAt !== projection.updatedAt
    || typeof document.updatedAt !== 'string'
    || Number.isNaN(Date.parse(document.updatedAt))
    || new Date(document.updatedAt).toISOString() !== document.updatedAt) {
    throw new LandlordPropertyDocumentListError(
      'INVALID_DOCUMENT_METADATA',
      'Document update time must match the source record and use normalized ISO format.',
    );
  }
  return Object.freeze({
    documentAccessId: projection.documentAccessId,
    propertyId: property.id,
    propertyLabel: safeLabel(projection.propertyLabel, 'property label', 160),
    documentName: safeLabel(projection.documentName, 'document name', 160),
    category: projection.category,
    contentType: projection.contentType,
    updatedAt: document.updatedAt,
  });
}

/** List safe document metadata for an actor’s active verified landlord properties. */
function createMyLandlordPropertyDocumentListUseCase({
  transaction,
  resolveLandlordDocumentAccess,
  queryVerifiedLandlordPropertyDocuments,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    resolveLandlordDocumentAccess,
    queryVerifiedLandlordPropertyDocuments,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new LandlordPropertyDocumentListError(
      'MISSING_ADAPTER',
      `Landlord document adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new LandlordPropertyDocumentListError('INVALID_CLOCK', 'A document list clock is required.');
  }

  return async function listMyLandlordPropertyDocuments({
    actorUserId,
    estateId,
    page = 1,
    pageSize = 25,
  } = {}) {
    if (!actorUserId || !estateId || !Number.isInteger(page) || page < 1
      || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new LandlordPropertyDocumentListError(
        'INVALID_INPUT',
        'Authenticated actor, estate and bounded pagination are required.',
      );
    }
    return transaction(async (tx) => {
      const access = await resolveLandlordDocumentAccess(tx, { actorUserId, estateId });
      if (!access || String(access.actorUserId) !== String(actorUserId)
        || String(access.estateId) !== String(estateId)
        || access.mayViewPropertyDocuments !== true) {
        throw new LandlordPropertyDocumentListError(
          'DOCUMENT_ACCESS_DENIED',
          'The actor cannot view property documents in this estate.',
        );
      }
      const asOf = new Date(clock());
      if (Number.isNaN(asOf.getTime())) {
        throw new LandlordPropertyDocumentListError('INVALID_CLOCK', 'A valid document query time is required.');
      }
      // Scope by active verified ownership before counting and pagination.
      const result = await queryVerifiedLandlordPropertyDocuments(tx, {
        access,
        estateId,
        actorUserId,
        page,
        pageSize,
        asOf: asOf.toISOString(),
      });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length) {
        throw new LandlordPropertyDocumentListError(
          'INVALID_REPOSITORY_RESULT',
          'The document query must return a bounded page and authorized total.',
        );
      }
      const seen = new Set();
      const seenAccessIds = new Set();
      const items = result.items.map((row) => {
        const id = String(row?.document?.id ?? '');
        const accessId = String(row?.projection?.documentAccessId ?? '');
        if (!id || seen.has(id) || !accessId || seenAccessIds.has(accessId)) {
          throw new LandlordPropertyDocumentListError(
            'INVALID_REPOSITORY_RESULT',
            'The document result contains a missing or duplicate document or access identifier.',
          );
        }
        seen.add(id);
        seenAccessIds.add(accessId);
        return projectLandlordPropertyDocument(row, actorUserId, estateId);
      });
      return Object.freeze({
        items: Object.freeze(items),
        page,
        pageSize,
        total: result.total,
        totalPages: Math.ceil(result.total / pageSize),
        asOf: asOf.toISOString(),
      });
    });
  };
}

module.exports = {
  LandlordPropertyDocumentListError,
  createMyLandlordPropertyDocumentListUseCase,
  projectLandlordPropertyDocument,
};
