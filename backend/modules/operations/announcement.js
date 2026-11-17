const AnnouncementStatus = Object.freeze({
  DRAFT: 'draft',
  SCHEDULED: 'scheduled',
  SENDING: 'sending',
  PUBLISHED: 'published',
  CANCELLED: 'cancelled',
  FAILED: 'failed',
});

const AnnouncementPriority = Object.freeze({ NORMAL: 'normal', EMERGENCY: 'emergency' });

class AnnouncementError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AnnouncementError';
    this.code = code;
  }
}

function parseInstant(value) {
  if (value === undefined || value === null || value === '') return null;
  const milliseconds = new Date(value).getTime();
  return Number.isNaN(milliseconds) ? null : milliseconds;
}

function validateTimeZone(timeZone) {
  if (typeof timeZone !== 'string' || !timeZone.trim()) return false;
  try {
    new Intl.DateTimeFormat('en', { timeZone }).format(0);
    return true;
  } catch {
    return false;
  }
}

function normalizeAudience(audience, estateId, estateTargets) {
  if (!audience || typeof audience !== 'object' || !estateId) {
    throw new AnnouncementError('INVALID_AUDIENCE', 'A supported estate audience is required.');
  }
  if (audience.type === 'all_residents') return Object.freeze({ type: 'all_residents' });
  if (audience.type === 'zone') {
    const zone = (estateTargets?.zones ?? []).find((candidate) =>
      candidate.id === audience.zoneId && candidate.estateId === estateId && candidate.status === 'active',
    );
    if (!zone) throw new AnnouncementError('INVALID_AUDIENCE_TARGET', 'Choose an active zone in this estate.');
    return Object.freeze({ type: 'zone', zoneId: zone.id });
  }
  if (audience.type === 'property_group') {
    if (typeof audience.propertyType !== 'string' || !estateTargets?.propertyTypes?.includes(audience.propertyType)) {
      throw new AnnouncementError('INVALID_AUDIENCE_TARGET', 'Choose a property type enabled for this estate.');
    }
    let zoneId = null;
    if (audience.zoneId !== undefined && audience.zoneId !== null) {
      const zone = (estateTargets?.zones ?? []).find((candidate) =>
        candidate.id === audience.zoneId && candidate.estateId === estateId && candidate.status === 'active',
      );
      if (!zone) throw new AnnouncementError('INVALID_AUDIENCE_TARGET', 'The selected zone is outside this estate.');
      zoneId = zone.id;
    }
    return Object.freeze({ type: 'property_group', propertyType: audience.propertyType, zoneId });
  }
  if (audience.type === 'role') {
    const role = (estateTargets?.roles ?? []).find((candidate) =>
      candidate.id === audience.roleId && candidate.estateId === estateId && candidate.active === true,
    );
    if (!role) throw new AnnouncementError('INVALID_AUDIENCE_TARGET', 'Choose an active audience role in this estate.');
    return Object.freeze({ type: 'role', roleId: role.id });
  }
  throw new AnnouncementError('INVALID_AUDIENCE', 'Recipient lists and unsupported audience types are not accepted.');
}

function prepareAnnouncementDraft(input, context) {
  const {
    estateId,
    actorUserId,
    title,
    body,
    priority = AnnouncementPriority.NORMAL,
    audience,
    channels,
    attachmentIds = [],
  } = input ?? {};
  if (!estateId || !actorUserId || context?.mayManageAnnouncements !== true) {
    throw new AnnouncementError('PERMISSION_DENIED', 'Announcement management permission is required.');
  }
  if (context.estateId !== estateId) {
    throw new AnnouncementError('ESTATE_SCOPE_MISMATCH', 'Announcement scope must match the authorized estate context.');
  }
  if (typeof title !== 'string' || !title.trim() || typeof body !== 'string' || !body.trim()) {
    throw new AnnouncementError('INVALID_CONTENT', 'Announcement title and message are required.');
  }
  if (!Object.values(AnnouncementPriority).includes(priority)) {
    throw new AnnouncementError('INVALID_PRIORITY', 'Choose a supported announcement priority.');
  }
  if (priority === AnnouncementPriority.EMERGENCY && context.maySendEmergency !== true) {
    throw new AnnouncementError('PERMISSION_DENIED', 'Emergency announcement permission is required.');
  }
  const selectedChannels = priority === AnnouncementPriority.EMERGENCY
    ? context.emergencyChannels
    : channels;
  if (!Array.isArray(selectedChannels) || selectedChannels.length === 0 || !Array.isArray(context.supportedChannels)
    || selectedChannels.some((channel) => !context.supportedChannels.includes(channel))
    || new Set(selectedChannels).size !== selectedChannels.length) {
    throw new AnnouncementError('INVALID_CHANNELS', 'Select available, unique notification channels.');
  }
  if (!Array.isArray(attachmentIds) || new Set(attachmentIds).size !== attachmentIds.length
    || attachmentIds.some((id) => !(context.authorizedAttachmentIds ?? []).includes(id))) {
    throw new AnnouncementError('INVALID_ATTACHMENT', 'Attachments must be authorized private files for this estate.');
  }
  const createdAtMs = parseInstant(context.now);
  if (createdAtMs === null) {
    throw new AnnouncementError('INVALID_TIMESTAMP', 'A valid draft creation time is required.');
  }

  return Object.freeze({
    estateId,
    createdByUserId: actorUserId,
    title: title.trim(),
    body: body.trim(),
    priority,
    audience: normalizeAudience(audience, estateId, context.estateTargets),
    channels: Object.freeze([...selectedChannels]),
    attachmentIds: Object.freeze([...attachmentIds]),
    status: AnnouncementStatus.DRAFT,
    createdAt: new Date(createdAtMs).toISOString(),
  });
}

function planAnnouncementSchedule(announcement, input) {
  if (!announcement?.id || !announcement.estateId || announcement.status !== AnnouncementStatus.DRAFT) {
    throw new AnnouncementError('INVALID_STATE', 'Only a draft announcement can be scheduled.');
  }
  const { actorUserId, mayManageAnnouncements, sendAt, timeZone, now } = input ?? {};
  const currentTime = parseInstant(now);
  const sendTime = parseInstant(sendAt);
  if (!actorUserId || mayManageAnnouncements !== true) {
    throw new AnnouncementError('PERMISSION_DENIED', 'Announcement management permission is required.');
  }
  if (announcement.priority === AnnouncementPriority.EMERGENCY) {
    throw new AnnouncementError('EMERGENCY_MUST_BE_IMMEDIATE', 'Emergency announcements must use the authorized immediate dispatch flow.');
  }
  if (typeof sendAt !== 'string' || !/(?:Z|[+-]\d{2}:\d{2})$/i.test(sendAt)
    || currentTime === null || sendTime === null || sendTime <= currentTime || !validateTimeZone(timeZone)) {
    throw new AnnouncementError('INVALID_SCHEDULE', 'Choose a future send time and valid estate timezone.');
  }

  const scheduledAt = new Date(sendTime).toISOString();
  const scheduleKey = `announcement.schedule:${announcement.id}:${scheduledAt}`;
  return Object.freeze({
    transactionRequired: true,
    announcementId: announcement.id,
    estateId: announcement.estateId,
    nextStatus: AnnouncementStatus.SCHEDULED,
    effects: Object.freeze([
      Object.freeze({
        type: 'announcement.scheduled',
        announcementId: announcement.id,
        estateId: announcement.estateId,
        from: AnnouncementStatus.DRAFT,
        to: AnnouncementStatus.SCHEDULED,
        scheduledAt,
        timeZone,
        actorUserId,
      }),
      Object.freeze({
        type: 'notification_job.enqueue',
        announcementId: announcement.id,
        estateId: announcement.estateId,
        scheduledAt,
        idempotencyKey: scheduleKey,
      }),
    ]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: announcement.estateId,
      action: 'announcement.schedule',
      targetType: 'announcement',
      targetId: announcement.id,
      outcome: 'success',
      occurredAt: new Date(currentTime).toISOString(),
    }),
  });
}

function planAnnouncementDispatch(announcement, input) {
  if (!announcement?.id || !announcement.estateId
    || ![AnnouncementStatus.DRAFT, AnnouncementStatus.SCHEDULED].includes(announcement.status)) {
    throw new AnnouncementError('INVALID_STATE', 'Only a draft or due scheduled announcement can be dispatched.');
  }
  const { actorUserId, mayDispatch, maySendEmergency, now, audienceSnapshotRef, recipientCount } = input ?? {};
  const currentTime = parseInstant(now);
  if (!actorUserId || mayDispatch !== true || currentTime === null) {
    throw new AnnouncementError('PERMISSION_DENIED', 'Authorized dispatch and a valid timestamp are required.');
  }
  if (announcement.status === AnnouncementStatus.SCHEDULED) {
    const scheduledTime = parseInstant(announcement.scheduledAt);
    if (scheduledTime === null || currentTime < scheduledTime) {
      throw new AnnouncementError('NOT_DUE', 'A scheduled announcement cannot be dispatched before its send time.');
    }
  }
  if (announcement.priority === AnnouncementPriority.EMERGENCY && maySendEmergency !== true) {
    throw new AnnouncementError('PERMISSION_DENIED', 'Emergency announcement permission is required.');
  }
  if (typeof audienceSnapshotRef !== 'string' || !audienceSnapshotRef.trim()
    || !Number.isInteger(recipientCount) || recipientCount < 0) {
    throw new AnnouncementError('AUDIENCE_RESOLUTION_REQUIRED', 'Resolve and snapshot eligible recipients at dispatch time.');
  }

  const dispatchedAt = new Date(currentTime).toISOString();
  const deliveryKey = `announcement.dispatch:${announcement.id}:${announcement.version ?? 1}`;
  return Object.freeze({
    transactionRequired: true,
    announcementId: announcement.id,
    estateId: announcement.estateId,
    nextStatus: AnnouncementStatus.SENDING,
    idempotencyKey: deliveryKey,
    effects: Object.freeze([
      Object.freeze({
        type: 'announcement.dispatch_started',
        announcementId: announcement.id,
        estateId: announcement.estateId,
        from: announcement.status,
        to: AnnouncementStatus.SENDING,
        audienceSnapshotRef: audienceSnapshotRef.trim(),
        dispatchAudienceSnapshotRef: audienceSnapshotRef.trim(),
        dispatchRecipientCount: recipientCount,
        dispatchIdempotencyKey: deliveryKey,
        actorUserId,
        dispatchedAt,
      }),
      Object.freeze({
        type: 'notification_dispatch.request',
        announcementId: announcement.id,
        estateId: announcement.estateId,
        audienceSnapshotRef: audienceSnapshotRef.trim(),
        channels: announcement.channels,
        idempotencyKey: deliveryKey,
      }),
    ]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: announcement.estateId,
      action: 'announcement.dispatch',
      targetType: 'announcement',
      targetId: announcement.id,
      outcome: 'success',
      occurredAt: dispatchedAt,
    }),
  });
}

function planDispatchAccepted(announcement, input) {
  if (!announcement?.id || !announcement.estateId || announcement.status !== AnnouncementStatus.SENDING) {
    throw new AnnouncementError('INVALID_STATE', 'Only a sending announcement can be marked accepted.');
  }
  const { notificationJobId, queuedCount, acceptedAt, actorUserId } = input ?? {};
  const timestamp = parseInstant(acceptedAt);
  if (!notificationJobId || !actorUserId || timestamp === null
    || !Number.isInteger(queuedCount) || queuedCount < 0
    || !Number.isInteger(announcement.dispatchRecipientCount)
    || queuedCount > announcement.dispatchRecipientCount) {
    throw new AnnouncementError('INVALID_DELIVERY_RECEIPT', 'Use an accepted notification-service result.');
  }

  const occurredAt = new Date(timestamp).toISOString();
  return Object.freeze({
    transactionRequired: true,
    announcementId: announcement.id,
    estateId: announcement.estateId,
    nextStatus: AnnouncementStatus.PUBLISHED,
    effects: Object.freeze([Object.freeze({
      type: 'announcement.dispatch_accepted',
      announcementId: announcement.id,
      estateId: announcement.estateId,
      from: AnnouncementStatus.SENDING,
      to: AnnouncementStatus.PUBLISHED,
      notificationJobId,
      deliverySummary: Object.freeze({ queued: queuedCount, delivered: 0, failed: 0, read: 0 }),
      acceptedAt: occurredAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: announcement.estateId,
      action: 'announcement.published',
      targetType: 'announcement',
      targetId: announcement.id,
      outcome: 'success',
      occurredAt,
    }),
  });
}

function planDispatchFailed(announcement, { actorUserId, now, failureCode } = {}) {
  const timestamp = parseInstant(now);
  if (!announcement?.id || !announcement.estateId || announcement.status !== AnnouncementStatus.SENDING
    || !actorUserId || timestamp === null || typeof failureCode !== 'string'
    || !/^[A-Z0-9_]{1,64}$/.test(failureCode)) {
    throw new AnnouncementError('INVALID_DELIVERY_FAILURE', 'A sending announcement and safe failure result are required.');
  }

  const failedAt = new Date(timestamp).toISOString();
  return Object.freeze({
    transactionRequired: true,
    announcementId: announcement.id,
    estateId: announcement.estateId,
    nextStatus: AnnouncementStatus.FAILED,
    effects: Object.freeze([Object.freeze({
      type: 'announcement.dispatch_failed',
      announcementId: announcement.id,
      estateId: announcement.estateId,
      from: AnnouncementStatus.SENDING,
      to: AnnouncementStatus.FAILED,
      failureCode,
      failedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: announcement.estateId,
      action: 'announcement.dispatch_failed',
      targetType: 'announcement',
      targetId: announcement.id,
      outcome: 'failure',
      occurredAt: failedAt,
    }),
  });
}

function planAnnouncementRetry(announcement, { actorUserId, mayDispatch, now } = {}) {
  const timestamp = parseInstant(now);
  if (!announcement?.id || !announcement.estateId || announcement.status !== AnnouncementStatus.FAILED
    || mayDispatch !== true || !actorUserId || timestamp === null
    || typeof announcement.dispatchAudienceSnapshotRef !== 'string'
    || !announcement.dispatchAudienceSnapshotRef
    || typeof announcement.dispatchIdempotencyKey !== 'string'
    || !announcement.dispatchIdempotencyKey) {
    throw new AnnouncementError('INVALID_RETRY', 'Retry requires an authorized failed delivery with its original audience and idempotency key.');
  }

  const retriedAt = new Date(timestamp).toISOString();
  return Object.freeze({
    transactionRequired: true,
    announcementId: announcement.id,
    estateId: announcement.estateId,
    nextStatus: AnnouncementStatus.SENDING,
    effects: Object.freeze([
      Object.freeze({
        type: 'announcement.retry_started',
        announcementId: announcement.id,
        estateId: announcement.estateId,
        from: AnnouncementStatus.FAILED,
        to: AnnouncementStatus.SENDING,
        actorUserId,
        retriedAt,
      }),
      Object.freeze({
        type: 'notification_dispatch.retry',
        announcementId: announcement.id,
        estateId: announcement.estateId,
        audienceSnapshotRef: announcement.dispatchAudienceSnapshotRef,
        channels: announcement.channels,
        idempotencyKey: announcement.dispatchIdempotencyKey,
      }),
    ]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: announcement.estateId,
      action: 'announcement.retry',
      targetType: 'announcement',
      targetId: announcement.id,
      outcome: 'success',
      occurredAt: retriedAt,
    }),
  });
}

function planScheduledCancellation(announcement, { actorUserId, mayManageAnnouncements, now, reason } = {}) {
  const timestamp = parseInstant(now);
  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  if (!announcement?.id || !announcement.estateId || announcement.status !== AnnouncementStatus.SCHEDULED) {
    throw new AnnouncementError('INVALID_STATE', 'Only a scheduled announcement can be cancelled.');
  }
  if (!actorUserId || mayManageAnnouncements !== true || timestamp === null || !normalizedReason) {
    throw new AnnouncementError('INVALID_CANCELLATION', 'Authorized actor, time, and cancellation reason are required.');
  }

  const cancelledAt = new Date(timestamp).toISOString();
  return Object.freeze({
    transactionRequired: true,
    announcementId: announcement.id,
    estateId: announcement.estateId,
    nextStatus: AnnouncementStatus.CANCELLED,
    effects: Object.freeze([
      Object.freeze({
        type: 'announcement.cancelled',
        announcementId: announcement.id,
        estateId: announcement.estateId,
        from: AnnouncementStatus.SCHEDULED,
        to: AnnouncementStatus.CANCELLED,
        actorUserId,
        reason: normalizedReason,
        cancelledAt,
      }),
      Object.freeze({
        type: 'notification_job.cancel',
        announcementId: announcement.id,
        idempotencyKey: `announcement.schedule:${announcement.id}:${announcement.scheduledAt}`,
      }),
    ]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: announcement.estateId,
      action: 'announcement.cancel',
      targetType: 'announcement',
      targetId: announcement.id,
      outcome: 'success',
      reason: normalizedReason,
      occurredAt: cancelledAt,
    }),
  });
}

module.exports = {
  AnnouncementError,
  AnnouncementPriority,
  AnnouncementStatus,
  normalizeAudience,
  planAnnouncementRetry,
  planAnnouncementDispatch,
  planDispatchFailed,
  planAnnouncementSchedule,
  planDispatchAccepted,
  planScheduledCancellation,
  prepareAnnouncementDraft,
};
