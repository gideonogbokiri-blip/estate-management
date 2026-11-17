class ResidentAnnouncementListError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResidentAnnouncementListError';
    this.code = code;
  }
}

const allowedFields = new Set([
  'notificationId',
  'announcementId',
  'title',
  'body',
  'category',
  'priority',
  'audienceLabel',
  'publishedAt',
  'readAt',
]);

function projectAnnouncementForRecipient(record, projection) {
  if (!record || record.status !== 'published'
    || !projection || typeof projection !== 'object' || Array.isArray(projection)
    || Object.keys(projection).some((field) => !allowedFields.has(field))) {
    throw new ResidentAnnouncementListError(
      'INVALID_ANNOUNCEMENT_PROJECTION',
      'The resident announcement projection contains unsupported data.',
    );
  }
  const text = (value, name, max, required = true) => {
    if (value === null || value === undefined) {
      if (!required) return null;
      throw new ResidentAnnouncementListError('INVALID_ANNOUNCEMENT_PROJECTION', `${name} is required.`);
    }
    if (typeof value !== 'string' || value.length > max || (required && !value.trim())) {
      throw new ResidentAnnouncementListError('INVALID_ANNOUNCEMENT_PROJECTION', `${name} is invalid.`);
    }
    return value;
  };
  const sameInstant = (value, name, required = true) => {
    if (value === null || value === undefined) {
      if (!required) return null;
      throw new ResidentAnnouncementListError('INVALID_ANNOUNCEMENT_PROJECTION', `${name} is required.`);
    }
    if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
      throw new ResidentAnnouncementListError('INVALID_ANNOUNCEMENT_PROJECTION', `${name} is invalid.`);
    }
    return new Date(Date.parse(value)).toISOString();
  };
  if (!record.id || !record.estateId || !record.notificationId
    || String(projection.announcementId) !== String(record.id)
    || String(projection.notificationId) !== String(record.notificationId)
    || projection.publishedAt !== record.publishedAt
    || projection.readAt !== (record.readAt ?? null)
    || !['normal', 'emergency'].includes(record.priority)) {
    throw new ResidentAnnouncementListError(
      'INVALID_ANNOUNCEMENT_PROJECTION',
      'The resident announcement does not match its authorized notification record.',
    );
  }
  return Object.freeze({
    notificationId: String(record.notificationId),
    id: String(record.id),
    estateId: String(record.estateId),
    title: text(projection.title, 'title', 120),
    body: text(projection.body, 'body', 4000),
    category: text(projection.category, 'category', 80),
    priority: record.priority,
    audienceLabel: text(projection.audienceLabel, 'audienceLabel', 120),
    publishedAt: sameInstant(projection.publishedAt, 'publishedAt'),
    readAt: sameInstant(projection.readAt, 'readAt', false),
    read: projection.readAt !== null,
  });
}

/** List only published announcements delivered to the authenticated actor. */
function createMyAnnouncementListUseCase({
  transaction,
  requireActor,
  queryRecipientAnnouncements,
  projectForRecipient,
} = {}) {
  const ports = { transaction, requireActor, queryRecipientAnnouncements, projectForRecipient };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new ResidentAnnouncementListError(
      'MISSING_ADAPTER',
      `Resident announcement list adapters are required: ${missing.join(', ')}.`,
    );
  }

  return async function listMyAnnouncements({ actorUserId, page = 1, pageSize = 25 } = {}) {
    if (!actorUserId || !Number.isInteger(page) || page < 1
      || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
      throw new ResidentAnnouncementListError(
        'INVALID_QUERY',
        'Authenticated actor and valid announcement pagination are required.',
      );
    }
    return transaction(async (tx) => {
      const actor = await requireActor(tx, { actorUserId });
      if (!actor || String(actor.userId) !== String(actorUserId) || actor.active !== true) {
        throw new ResidentAnnouncementListError(
          'ACTOR_NOT_ACTIVE',
          'An active authenticated account is required to view announcements.',
        );
      }
      // The host query must derive estate memberships and recipient delivery
      // records from actorUserId before ordering or applying pagination.
      const result = await queryRecipientAnnouncements(tx, {
        actorUserId,
        actor,
        page,
        pageSize,
      });
      if (!result || !Array.isArray(result.items) || result.items.length > pageSize
        || !Number.isSafeInteger(result.total) || result.total < result.items.length
        || (result.items.length && (page - 1) * pageSize >= result.total)) {
        throw new ResidentAnnouncementListError(
          'INVALID_REPOSITORY_RESULT',
          'The notification service returned an invalid resident announcement page.',
        );
      }
      const seen = new Set();
      const items = [];
      for (const record of result.items) {
        if (!record?.id || !record.estateId || !record.notificationId
          || record.status !== 'published') {
          throw new ResidentAnnouncementListError(
            'INVALID_RECIPIENT_RECORD',
            'Only published announcements addressed to this resident can be listed.',
          );
        }
        const key = `${record.estateId}:${record.id}:${record.notificationId}`;
        if (seen.has(key)) {
          throw new ResidentAnnouncementListError('DUPLICATE_RESULT', 'The resident announcement page contains a duplicate.');
        }
        seen.add(key);
        const projection = await projectForRecipient({ actorUserId, actor, record, tx });
        items.push(projectAnnouncementForRecipient(record, projection));
      }
      return Object.freeze({
        items: Object.freeze(items),
        page,
        pageSize,
        total: result.total,
        totalPages: Math.ceil(result.total / pageSize),
      });
    });
  };
}

module.exports = {
  ResidentAnnouncementListError,
  createMyAnnouncementListUseCase,
  projectAnnouncementForRecipient,
};
