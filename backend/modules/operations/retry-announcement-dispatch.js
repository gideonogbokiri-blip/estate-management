const { AnnouncementError, AnnouncementStatus, planAnnouncementRetry } = require('./announcement');

class AnnouncementRetryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AnnouncementRetryError';
    this.code = code;
  }
}

/** Retry a failed dispatch against the exact original audience and delivery key. */
function retryAnnouncementDispatchUseCase({
  transaction,
  requireEstatePermission,
  findAnnouncementForUpdate,
  findNotificationDispatchByKey,
  markAnnouncementRetrying,
  enqueueNotificationRetry,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    findAnnouncementForUpdate,
    findNotificationDispatchByKey,
    markAnnouncementRetrying,
    enqueueNotificationRetry,
    appendAuditEvent,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new AnnouncementRetryError(
      'MISSING_ADAPTER',
      `Announcement retry adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new AnnouncementRetryError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function retryAnnouncementDispatch({ actorUserId, estateId, announcementId } = {}) {
    if (!actorUserId || !estateId || !announcementId) {
      throw new AnnouncementRetryError(
        'INVALID_INPUT',
        'Authenticated actor, estate context and announcement are required.',
      );
    }
    return transaction(async (tx) => {
      const context = await requireEstatePermission(
        actorUserId,
        estateId,
        'announcement.manage',
        tx,
      );
      if (!context || String(context.estateId) !== String(estateId)) {
        throw new AnnouncementRetryError(
          'ESTATE_ACCESS_DENIED',
          'The actor cannot retry announcements in this estate.',
        );
      }
      const announcement = await findAnnouncementForUpdate(tx, {
        actorUserId,
        estateId,
        announcementId,
      });
      if (!announcement || String(announcement.id) !== String(announcementId)
        || String(announcement.estateId) !== String(estateId)) {
        throw new AnnouncementRetryError(
          'ANNOUNCEMENT_NOT_FOUND',
          'The announcement was not found in this estate.',
        );
      }
      if (!announcement.dispatchIdempotencyKey
        || !announcement.dispatchAudienceSnapshotRef) {
        throw new AnnouncementRetryError(
          'RETRY_CONTEXT_MISSING',
          'The original audience snapshot and dispatch key are required for retry.',
        );
      }
      const original = await findNotificationDispatchByKey(tx, {
        actorUserId,
        estateId,
        announcementId,
        idempotencyKey: announcement.dispatchIdempotencyKey,
      });
      if (!original || String(original.announcementId) !== String(announcementId)
        || String(original.estateId) !== String(estateId)
        || original.idempotencyKey !== announcement.dispatchIdempotencyKey
        || original.audienceSnapshotRef !== announcement.dispatchAudienceSnapshotRef
        || !Array.isArray(original.channels)
        || original.channels.length !== announcement.channels?.length
        || original.channels.some((channel) => !announcement.channels.includes(channel))) {
        throw new AnnouncementRetryError(
          'ORIGINAL_DISPATCH_MISMATCH',
          'The original notification dispatch could not be verified for retry.',
        );
      }

      const plan = planAnnouncementRetry(announcement, {
        actorUserId,
        mayDispatch: true,
        now: clock(),
      });
      const updated = await markAnnouncementRetrying(tx, {
        actorUserId,
        announcementId,
        estateId,
        expectedStatus: AnnouncementStatus.FAILED,
        expectedVersion: announcement.version ?? 1,
        status: AnnouncementStatus.SENDING,
        idempotencyKey: announcement.dispatchIdempotencyKey,
        audienceSnapshotRef: announcement.dispatchAudienceSnapshotRef,
      });
      if (!updated || String(updated.id) !== String(announcementId)
        || String(updated.estateId) !== String(estateId)
        || updated.status !== AnnouncementStatus.SENDING
        || updated.dispatchIdempotencyKey !== announcement.dispatchIdempotencyKey) {
        throw new AnnouncementRetryError(
          'CONCURRENT_UPDATE',
          'The announcement changed before retry could start. Reload and try again.',
        );
      }

      const retry = plan.effects[1];
      const job = await enqueueNotificationRetry(tx, {
        announcementId,
        estateId,
        audienceSnapshotRef: retry.audienceSnapshotRef,
        channels: retry.channels,
        idempotencyKey: retry.idempotencyKey,
      });
      if (!job || String(job.announcementId) !== String(announcementId)
        || String(job.estateId) !== String(estateId)
        || job.idempotencyKey !== retry.idempotencyKey || !job.jobId) {
        throw new AnnouncementRetryError(
          'RETRY_ENQUEUE_FAILED',
          'The idempotent notification retry could not be recorded.',
        );
      }
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        announcementId,
        estateId,
        status: AnnouncementStatus.SENDING,
        jobId: job.jobId,
        replayed: false,
      });
    }).catch((error) => {
      if (error instanceof AnnouncementRetryError) throw error;
      if (error instanceof AnnouncementError) {
        throw new AnnouncementRetryError(error.code, error.message);
      }
      throw error;
    });
  };
}

module.exports = { AnnouncementRetryError, retryAnnouncementDispatchUseCase };
