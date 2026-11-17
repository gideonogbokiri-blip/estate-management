class ResidentAnnouncementReadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResidentAnnouncementReadError';
    this.code = code;
  }
}

/** Mark a delivered announcement notification read through Zvend's read service. */
function markMyAnnouncementReadUseCase({
  transaction,
  requireActor,
  findRecipientAnnouncementForUpdate,
  markNotificationRead,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, requireActor, findRecipientAnnouncementForUpdate, markNotificationRead };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new ResidentAnnouncementReadError(
      'MISSING_ADAPTER',
      `Resident announcement read adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new ResidentAnnouncementReadError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function markMyAnnouncementRead({ actorUserId, announcementId } = {}) {
    if (!actorUserId || !announcementId) {
      throw new ResidentAnnouncementReadError(
        'INVALID_INPUT',
        'Authenticated actor and announcement are required.',
      );
    }
    return transaction(async (tx) => {
      const actor = await requireActor(tx, { actorUserId });
      if (!actor || String(actor.userId) !== String(actorUserId) || actor.active !== true) {
        throw new ResidentAnnouncementReadError(
          'ACTOR_NOT_ACTIVE',
          'An active authenticated account is required to mark an announcement read.',
        );
      }
      const recipientRecord = await findRecipientAnnouncementForUpdate(tx, {
        actorUserId,
        announcementId,
        actor,
      });
      if (!recipientRecord
        || String(recipientRecord.announcementId) !== String(announcementId)
        || String(recipientRecord.userId) !== String(actorUserId)
        || recipientRecord.announcementStatus !== 'published'
        || !recipientRecord.notificationId || !recipientRecord.estateId) {
        throw new ResidentAnnouncementReadError(
          'ANNOUNCEMENT_NOT_AVAILABLE',
          'This announcement is not available to the current resident.',
        );
      }
      const now = clock();
      if (!(now instanceof Date) || Number.isNaN(now.getTime())) {
        throw new ResidentAnnouncementReadError(
          'INVALID_CLOCK',
          'A valid read timestamp is required.',
        );
      }
      const readAt = new Date(now).toISOString();
      const result = await markNotificationRead(tx, {
        actorUserId,
        estateId: recipientRecord.estateId,
        notificationId: recipientRecord.notificationId,
        announcementId,
        occurredAt: readAt,
      });
      if (!result || String(result.notificationId) !== String(recipientRecord.notificationId)
        || String(result.announcementId) !== String(announcementId)
        || String(result.userId) !== String(actorUserId)
        || typeof result.readAt !== 'string' || Number.isNaN(Date.parse(result.readAt))) {
        throw new ResidentAnnouncementReadError(
          'INVALID_READ_RESULT',
          'The notification service did not confirm the read state.',
        );
      }
      return Object.freeze({
        announcementId: String(announcementId),
        notificationId: String(recipientRecord.notificationId),
        readAt: new Date(Date.parse(result.readAt)).toISOString(),
        alreadyRead: result.alreadyRead === true,
      });
    });
  };
}

module.exports = { ResidentAnnouncementReadError, markMyAnnouncementReadUseCase };
