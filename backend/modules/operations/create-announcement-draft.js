const { prepareAnnouncementDraft, AnnouncementError } = require('./announcement');

class AnnouncementDraftCreationError extends Error {
  constructor(code, message, options) {
    super(message, options);
    this.name = 'AnnouncementDraftCreationError';
    this.code = code;
  }
}

/** Create an estate-scoped draft and its audit record in one host transaction. */
function createAnnouncementDraftUseCase({
  transaction,
  loadAnnouncementContext,
  generateAnnouncementId,
  createAnnouncementRecord,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    loadAnnouncementContext,
    generateAnnouncementId,
    createAnnouncementRecord,
    appendAuditEvent,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new AnnouncementDraftCreationError(
      'MISSING_ADAPTER',
      `Announcement draft adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new AnnouncementDraftCreationError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function createAnnouncementDraft({ actorUserId, estateId, ...input } = {}) {
    if (!actorUserId || !estateId) {
      throw new AnnouncementDraftCreationError(
        'INVALID_INPUT',
        'Authenticated actor and estate context are required.',
      );
    }

    return transaction(async (tx) => {
      const context = await loadAnnouncementContext(tx, { actorUserId, estateId });
      if (!context || String(context.estateId) !== String(estateId)) {
        throw new AnnouncementDraftCreationError(
          'ESTATE_ACCESS_DENIED',
          'The actor cannot create announcements in this estate.',
        );
      }

      const now = clock();
      const planned = prepareAnnouncementDraft(
        { ...input, actorUserId, estateId },
        { ...context, estateId: context.estateId, now },
      );
      const id = await generateAnnouncementId(tx, { estateId });
      if (!id) {
        throw new AnnouncementDraftCreationError(
          'INVALID_ANNOUNCEMENT_ID',
          'An announcement reference could not be generated.',
        );
      }
      const record = Object.freeze({ ...planned, id, version: 1 });
      const created = await createAnnouncementRecord(tx, record);
      if (!created || String(created.id) !== String(id)
        || String(created.estateId) !== String(estateId)
        || String(created.createdByUserId) !== String(actorUserId)
        || created.status !== 'draft') {
        throw new AnnouncementDraftCreationError(
          'INVALID_CREATE_RESULT',
          'The repository did not persist the announcement in the selected estate.',
        );
      }

      await appendAuditEvent(tx, {
        actorUserId,
        scope: 'estate',
        estateId,
        action: 'announcement.create_draft',
        targetType: 'announcement',
        targetId: id,
        outcome: 'success',
        occurredAt: planned.createdAt,
      });

      return Object.freeze({
        id,
        estateId,
        status: 'draft',
        title: planned.title,
        priority: planned.priority,
        audience: planned.audience,
        channels: planned.channels,
        createdAt: planned.createdAt,
      });
    }).catch((error) => {
      if (error instanceof AnnouncementDraftCreationError) throw error;
      if (error instanceof AnnouncementError) {
        throw new AnnouncementDraftCreationError(error.code, error.message);
      }
      throw error;
    });
  };
}

module.exports = { AnnouncementDraftCreationError, createAnnouncementDraftUseCase };
