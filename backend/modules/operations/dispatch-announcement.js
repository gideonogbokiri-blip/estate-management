const { AnnouncementError, AnnouncementStatus, planAnnouncementDispatch } = require('./announcement');

class AnnouncementDispatchError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AnnouncementDispatchError';
    this.code = code;
  }
}

/** Resolve eligible recipients and enqueue an idempotent dispatch request. */
function dispatchAnnouncementUseCase({
  transaction,
  requireEstatePermission,
  findAnnouncementForUpdate,
  resolveAnnouncementAudience,
  findAnnouncementDispatchRequest,
  beginAnnouncementDispatch,
  enqueueNotificationDispatch,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    findAnnouncementForUpdate,
    resolveAnnouncementAudience,
    findAnnouncementDispatchRequest,
    beginAnnouncementDispatch,
    enqueueNotificationDispatch,
    appendAuditEvent,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new AnnouncementDispatchError(
      'MISSING_ADAPTER',
      `Announcement dispatch adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new AnnouncementDispatchError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function dispatchAnnouncement({
    actorUserId,
    estateId,
    announcementId,
    confirmEmergency = false,
  } = {}) {
    if (!actorUserId || !estateId || !announcementId) {
      throw new AnnouncementDispatchError(
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
        throw new AnnouncementDispatchError(
          'ESTATE_ACCESS_DENIED',
          'The actor cannot dispatch announcements in this estate.',
        );
      }
      const announcement = await findAnnouncementForUpdate(tx, {
        actorUserId,
        estateId,
        announcementId,
      });
      if (!announcement || String(announcement.id) !== String(announcementId)
        || String(announcement.estateId) !== String(estateId)) {
        throw new AnnouncementDispatchError(
          'ANNOUNCEMENT_NOT_FOUND',
          'The announcement was not found in this estate.',
        );
      }

      const emergency = announcement.priority === 'emergency';
      if (emergency) {
        if (confirmEmergency !== true) {
          throw new AnnouncementDispatchError(
            'EMERGENCY_CONFIRMATION_REQUIRED',
            'Explicit confirmation is required for an emergency announcement.',
          );
        }
        const emergencyContext = await requireEstatePermission(
          actorUserId,
          estateId,
          'announcement.emergency',
          tx,
        );
        if (!emergencyContext || String(emergencyContext.estateId) !== String(estateId)) {
          throw new AnnouncementDispatchError(
            'EMERGENCY_PERMISSION_DENIED',
            'Emergency announcement permission is required.',
          );
        }
      }

      if (announcement.status === AnnouncementStatus.SENDING) {
        const idempotencyKey = announcement.dispatchIdempotencyKey;
        const request = await findAnnouncementDispatchRequest(tx, {
          actorUserId,
          estateId,
          announcementId,
          idempotencyKey,
        });
        if (!idempotencyKey || !request
          || String(request.announcementId) !== String(announcementId)
          || String(request.estateId) !== String(estateId)
          || request.idempotencyKey !== idempotencyKey || !request.requestId) {
          throw new AnnouncementDispatchError(
            'DISPATCH_REQUEST_NOT_FOUND',
            'The existing dispatch request could not be verified.',
          );
        }
        return Object.freeze({
          announcementId,
          estateId,
          status: AnnouncementStatus.SENDING,
          requestId: request.requestId,
          replayed: true,
        });
      }

      const now = clock();
      const audience = await resolveAnnouncementAudience(tx, {
        actorUserId,
        estateId,
        context,
        announcement,
      });
      if (!audience || typeof audience.snapshotRef !== 'string'
        || !audience.snapshotRef.trim() || !Number.isInteger(audience.recipientCount)
        || audience.recipientCount < 0 || String(audience.estateId) !== String(estateId)) {
        throw new AnnouncementDispatchError(
          'AUDIENCE_RESOLUTION_FAILED',
          'The server could not safely resolve this announcement audience.',
        );
      }

      const plan = planAnnouncementDispatch(announcement, {
        actorUserId,
        mayDispatch: true,
        maySendEmergency: emergency,
        now,
        audienceSnapshotRef: audience.snapshotRef,
        recipientCount: audience.recipientCount,
      });
      const start = plan.effects[0];
      const updated = await beginAnnouncementDispatch(tx, {
        actorUserId,
        announcementId,
        estateId,
        expectedStatus: announcement.status,
        expectedVersion: announcement.version ?? 1,
        status: AnnouncementStatus.SENDING,
        dispatchRequestedByUserId: actorUserId,
        audienceSnapshotRef: start.audienceSnapshotRef,
        recipientCount: start.dispatchRecipientCount,
        idempotencyKey: plan.idempotencyKey,
        dispatchedAt: start.dispatchedAt,
      });
      if (!updated || String(updated.id) !== String(announcementId)
        || String(updated.estateId) !== String(estateId)
        || updated.status !== AnnouncementStatus.SENDING
        || updated.dispatchAudienceSnapshotRef !== start.audienceSnapshotRef
        || updated.dispatchRecipientCount !== audience.recipientCount
        || updated.dispatchIdempotencyKey !== plan.idempotencyKey
        || String(updated.dispatchRequestedByUserId) !== String(actorUserId)) {
        throw new AnnouncementDispatchError(
          'CONCURRENT_UPDATE',
          'The announcement changed before dispatch could start. Reload and try again.',
        );
      }

      const request = await enqueueNotificationDispatch(tx, {
        announcementId,
        estateId,
        audienceSnapshotRef: start.audienceSnapshotRef,
        channels: start.channels,
        idempotencyKey: plan.idempotencyKey,
      });
      if (!request || String(request.announcementId) !== String(announcementId)
        || String(request.estateId) !== String(estateId)
        || request.idempotencyKey !== plan.idempotencyKey || !request.requestId) {
        throw new AnnouncementDispatchError(
          'DISPATCH_ENQUEUE_FAILED',
          'The notification dispatch request could not be recorded.',
        );
      }

      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        announcementId,
        estateId,
        status: AnnouncementStatus.SENDING,
        requestId: request.requestId,
        replayed: false,
      });
    }).catch((error) => {
      if (error instanceof AnnouncementDispatchError) throw error;
      if (error instanceof AnnouncementError) {
        throw new AnnouncementDispatchError(error.code, error.message);
      }
      throw error;
    });
  };
}

module.exports = { AnnouncementDispatchError, dispatchAnnouncementUseCase };
