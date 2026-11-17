const { AnnouncementError, AnnouncementStatus, planDispatchAccepted } = require('./announcement');

class AnnouncementDispatchAcceptanceError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AnnouncementDispatchAcceptanceError';
    this.code = code;
  }
}

/** Apply a notification-service acceptance receipt to its matching dispatch. */
function acceptAnnouncementDispatchUseCase({
  transaction,
  verifyNotificationAcceptance,
  findAnnouncementForUpdate,
  findDispatchAcceptanceByKey,
  commitDispatchAcceptance,
  appendAuditEvent,
} = {}) {
  const ports = {
    transaction,
    verifyNotificationAcceptance,
    findAnnouncementForUpdate,
    findDispatchAcceptanceByKey,
    commitDispatchAcceptance,
    appendAuditEvent,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new AnnouncementDispatchAcceptanceError(
      'MISSING_ADAPTER',
      `Dispatch acceptance adapters are required: ${missing.join(', ')}.`,
    );
  }

  return async function acceptAnnouncementDispatch({ event } = {}) {
    if (!event || typeof event !== 'object' || Array.isArray(event)) {
      throw new AnnouncementDispatchAcceptanceError(
        'INVALID_RECEIPT',
        'A notification-service acceptance event is required.',
      );
    }

    return transaction(async (tx) => {
      // This adapter must authenticate the service callback and return only
      // fields read from its trusted acceptance receipt.
      const receipt = await verifyNotificationAcceptance(tx, { event });
      if (!receipt || !receipt.announcementId || !receipt.estateId
        || typeof receipt.idempotencyKey !== 'string' || !receipt.idempotencyKey
        || !receipt.notificationJobId || !Number.isInteger(receipt.queuedCount)
        || receipt.queuedCount < 0 || typeof receipt.acceptedAt !== 'string'
        || Number.isNaN(Date.parse(receipt.acceptedAt))) {
        throw new AnnouncementDispatchAcceptanceError(
          'UNTRUSTED_RECEIPT',
          'The notification service did not provide a valid acceptance receipt.',
        );
      }

      const announcement = await findAnnouncementForUpdate(tx, {
        estateId: receipt.estateId,
        announcementId: receipt.announcementId,
      });
      if (!announcement || String(announcement.id) !== String(receipt.announcementId)
        || String(announcement.estateId) !== String(receipt.estateId)) {
        throw new AnnouncementDispatchAcceptanceError(
          'ANNOUNCEMENT_NOT_FOUND',
          'The accepted announcement was not found in its recorded estate.',
        );
      }

      // Locking the announcement before checking the receipt makes concurrent
      // duplicate callbacks observe the first transaction's committed result.
      const prior = await findDispatchAcceptanceByKey(tx, {
        estateId: receipt.estateId,
        announcementId: receipt.announcementId,
        idempotencyKey: receipt.idempotencyKey,
      });
      if (prior) {
        if (String(prior.announcementId) !== String(receipt.announcementId)
          || String(prior.estateId) !== String(receipt.estateId)
          || prior.idempotencyKey !== receipt.idempotencyKey
          || String(prior.notificationJobId) !== String(receipt.notificationJobId)
          || prior.queuedCount !== receipt.queuedCount
          || prior.acceptedAt !== new Date(Date.parse(receipt.acceptedAt)).toISOString()) {
          throw new AnnouncementDispatchAcceptanceError(
            'IDEMPOTENCY_CONFLICT',
            'This dispatch key already has a different acceptance receipt.',
          );
        }
        return Object.freeze({
          announcementId: receipt.announcementId,
          estateId: receipt.estateId,
          status: AnnouncementStatus.PUBLISHED,
          notificationJobId: receipt.notificationJobId,
          replayed: true,
        });
      }

      if (announcement.status !== AnnouncementStatus.SENDING
        || announcement.dispatchIdempotencyKey !== receipt.idempotencyKey
        || !announcement.dispatchRequestedByUserId) {
        throw new AnnouncementDispatchAcceptanceError(
          'DISPATCH_MISMATCH',
          'The acceptance receipt does not match the announcement dispatch in progress.',
        );
      }

      const plan = planDispatchAccepted(announcement, {
        actorUserId: announcement.dispatchRequestedByUserId,
        notificationJobId: receipt.notificationJobId,
        queuedCount: receipt.queuedCount,
        acceptedAt: receipt.acceptedAt,
      });
      const accepted = plan.effects[0];
      const committed = await commitDispatchAcceptance(tx, {
        announcementId: receipt.announcementId,
        estateId: receipt.estateId,
        expectedStatus: AnnouncementStatus.SENDING,
        expectedVersion: announcement.version ?? 1,
        status: AnnouncementStatus.PUBLISHED,
        notificationJobId: receipt.notificationJobId,
        deliverySummary: accepted.deliverySummary,
        publishedAt: accepted.acceptedAt,
        idempotencyKey: receipt.idempotencyKey,
        acceptedAt: new Date(Date.parse(receipt.acceptedAt)).toISOString(),
        queuedCount: receipt.queuedCount,
      });
      if (!committed || String(committed.announcementId) !== String(receipt.announcementId)
        || String(committed.estateId) !== String(receipt.estateId)
        || committed.status !== AnnouncementStatus.PUBLISHED
        || String(committed.notificationJobId) !== String(receipt.notificationJobId)
        || committed.idempotencyKey !== receipt.idempotencyKey) {
        throw new AnnouncementDispatchAcceptanceError(
          'CONCURRENT_UPDATE',
          'The dispatch acceptance could not be committed to the announcement.',
        );
      }

      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        announcementId: receipt.announcementId,
        estateId: receipt.estateId,
        status: AnnouncementStatus.PUBLISHED,
        notificationJobId: receipt.notificationJobId,
        replayed: false,
      });
    }).catch((error) => {
      if (error instanceof AnnouncementDispatchAcceptanceError) throw error;
      if (error instanceof AnnouncementError) {
        throw new AnnouncementDispatchAcceptanceError(error.code, error.message);
      }
      throw error;
    });
  };
}

module.exports = {
  AnnouncementDispatchAcceptanceError,
  acceptAnnouncementDispatchUseCase,
};
