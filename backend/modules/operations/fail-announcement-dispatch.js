const { AnnouncementError, AnnouncementStatus, planDispatchFailed } = require('./announcement');

class AnnouncementDispatchFailureError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AnnouncementDispatchFailureError';
    this.code = code;
  }
}

/** Apply a trusted notification-service failure receipt to a sending record. */
function failAnnouncementDispatchUseCase({
  transaction,
  verifyNotificationFailure,
  findAnnouncementForUpdate,
  findDispatchFailureByReceiptId,
  commitDispatchFailure,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    verifyNotificationFailure,
    findAnnouncementForUpdate,
    findDispatchFailureByReceiptId,
    commitDispatchFailure,
    appendAuditEvent,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new AnnouncementDispatchFailureError(
      'MISSING_ADAPTER',
      `Dispatch failure adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new AnnouncementDispatchFailureError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function failAnnouncementDispatch({ event } = {}) {
    if (!event || typeof event !== 'object' || Array.isArray(event)) {
      throw new AnnouncementDispatchFailureError(
        'INVALID_RECEIPT',
        'A notification-service failure event is required.',
      );
    }

    return transaction(async (tx) => {
      // Verify callback authenticity and map it to the persisted dispatch.
      const receipt = await verifyNotificationFailure(tx, { event });
      if (!receipt || !receipt.announcementId || !receipt.estateId
        || typeof receipt.receiptId !== 'string' || !receipt.receiptId.trim()
        || typeof receipt.idempotencyKey !== 'string' || !receipt.idempotencyKey
        || typeof receipt.failureCode !== 'string'
        || !/^[A-Z0-9_]{1,64}$/.test(receipt.failureCode)
        || typeof receipt.failedAt !== 'string' || Number.isNaN(Date.parse(receipt.failedAt))) {
        throw new AnnouncementDispatchFailureError(
          'UNTRUSTED_RECEIPT',
          'The notification service did not provide a valid failure receipt.',
        );
      }

      const announcement = await findAnnouncementForUpdate(tx, {
        estateId: receipt.estateId,
        announcementId: receipt.announcementId,
      });
      if (!announcement || String(announcement.id) !== String(receipt.announcementId)
        || String(announcement.estateId) !== String(receipt.estateId)) {
        throw new AnnouncementDispatchFailureError(
          'ANNOUNCEMENT_NOT_FOUND',
          'The failed announcement was not found in its recorded estate.',
        );
      }

      // Serialize callbacks before the receipt lookup so concurrent duplicates
      // can return the result committed by the first callback.
      const prior = await findDispatchFailureByReceiptId(tx, {
        estateId: receipt.estateId,
        announcementId: receipt.announcementId,
        receiptId: receipt.receiptId,
        idempotencyKey: receipt.idempotencyKey,
      });
      if (prior) {
        if (String(prior.announcementId) !== String(receipt.announcementId)
          || String(prior.estateId) !== String(receipt.estateId)
          || prior.receiptId !== receipt.receiptId
          || prior.idempotencyKey !== receipt.idempotencyKey
          || prior.failureCode !== receipt.failureCode
          || prior.failedAt !== new Date(Date.parse(receipt.failedAt)).toISOString()) {
          throw new AnnouncementDispatchFailureError(
            'IDEMPOTENCY_CONFLICT',
            'This notification failure receipt ID already has different contents.',
          );
        }
        return Object.freeze({
          announcementId: receipt.announcementId,
          estateId: receipt.estateId,
          status: announcement.status,
          failureCode: receipt.failureCode,
          replayed: true,
          stale: announcement.status !== AnnouncementStatus.FAILED,
        });
      }
      if (announcement.status !== AnnouncementStatus.SENDING
        || announcement.dispatchIdempotencyKey !== receipt.idempotencyKey
        || !announcement.dispatchRequestedByUserId) {
        throw new AnnouncementDispatchFailureError(
          'DISPATCH_MISMATCH',
          'The failure receipt does not match the announcement dispatch in progress.',
        );
      }

      const plan = planDispatchFailed(announcement, {
        actorUserId: announcement.dispatchRequestedByUserId,
        now: receipt.failedAt || clock(),
        failureCode: receipt.failureCode,
      });
      const failed = plan.effects[0];
      const committed = await commitDispatchFailure(tx, {
        announcementId: receipt.announcementId,
        estateId: receipt.estateId,
        expectedStatus: AnnouncementStatus.SENDING,
        expectedVersion: announcement.version ?? 1,
        status: AnnouncementStatus.FAILED,
        idempotencyKey: receipt.idempotencyKey,
        receiptId: receipt.receiptId,
        failureCode: failed.failureCode,
        failedAt: failed.failedAt,
      });
      if (!committed || String(committed.announcementId) !== String(receipt.announcementId)
        || String(committed.estateId) !== String(receipt.estateId)
        || committed.status !== AnnouncementStatus.FAILED
        || committed.idempotencyKey !== receipt.idempotencyKey
        || committed.receiptId !== receipt.receiptId
        || committed.failureCode !== receipt.failureCode) {
        throw new AnnouncementDispatchFailureError(
          'CONCURRENT_UPDATE',
          'The dispatch failure could not be committed to the announcement.',
        );
      }

      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        announcementId: receipt.announcementId,
        estateId: receipt.estateId,
        status: AnnouncementStatus.FAILED,
        failureCode: receipt.failureCode,
        replayed: false,
      });
    }).catch((error) => {
      if (error instanceof AnnouncementDispatchFailureError) throw error;
      if (error instanceof AnnouncementError) {
        throw new AnnouncementDispatchFailureError(error.code, error.message);
      }
      throw error;
    });
  };
}

module.exports = {
  AnnouncementDispatchFailureError,
  failAnnouncementDispatchUseCase,
};
