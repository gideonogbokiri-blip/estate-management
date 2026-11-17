const { AnnouncementError, AnnouncementStatus, planAnnouncementSchedule } = require('./announcement');

class AnnouncementScheduleError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'AnnouncementScheduleError';
    this.code = code;
  }
}

/** Schedule a draft and enqueue its delivery job atomically in host adapters. */
function scheduleAnnouncementUseCase({
  transaction,
  requireEstatePermission,
  loadEstateTimeZone,
  findAnnouncementForUpdate,
  findScheduledAnnouncementJob,
  updateAnnouncementSchedule,
  enqueueScheduledAnnouncement,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const ports = {
    transaction,
    requireEstatePermission,
    loadEstateTimeZone,
    findAnnouncementForUpdate,
    findScheduledAnnouncementJob,
    updateAnnouncementSchedule,
    enqueueScheduledAnnouncement,
    appendAuditEvent,
  };
  const missing = Object.entries(ports)
    .filter(([, port]) => typeof port !== 'function')
    .map(([name]) => name);
  if (missing.length) {
    throw new AnnouncementScheduleError(
      'MISSING_ADAPTER',
      `Announcement scheduling adapters are required: ${missing.join(', ')}.`,
    );
  }
  if (typeof clock !== 'function') {
    throw new AnnouncementScheduleError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function scheduleAnnouncement({ actorUserId, estateId, announcementId, sendAt, timeZone } = {}) {
    if (!actorUserId || !estateId || !announcementId) {
      throw new AnnouncementScheduleError(
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
        throw new AnnouncementScheduleError(
          'ESTATE_ACCESS_DENIED',
          'The actor cannot schedule announcements in this estate.',
        );
      }
      const estateTimeZone = await loadEstateTimeZone(tx, { estateId, context });
      if (typeof estateTimeZone !== 'string' || estateTimeZone !== timeZone) {
        throw new AnnouncementScheduleError(
          'INVALID_TIME_ZONE',
          'Use the configured timezone for this estate.',
        );
      }

      const announcement = await findAnnouncementForUpdate(tx, {
        actorUserId,
        estateId,
        announcementId,
      });
      if (!announcement || String(announcement.id) !== String(announcementId)
        || String(announcement.estateId) !== String(estateId)) {
        throw new AnnouncementScheduleError(
          'ANNOUNCEMENT_NOT_FOUND',
          'The announcement was not found in this estate.',
        );
      }
      const requestedInstant = typeof sendAt === 'string'
        && /(?:Z|[+-]\d{2}:\d{2})$/i.test(sendAt)
        ? Date.parse(sendAt)
        : Number.NaN;
      if (announcement.status === AnnouncementStatus.SCHEDULED
        && Number.isFinite(requestedInstant)
        && new Date(requestedInstant).toISOString() === announcement.scheduledAt
        && announcement.timeZone === timeZone) {
        const idempotencyKey = `announcement.schedule:${announcementId}:${announcement.scheduledAt}`;
        const existingJob = await findScheduledAnnouncementJob(tx, {
          actorUserId,
          estateId,
          announcementId,
          idempotencyKey,
        });
        if (!existingJob || String(existingJob.announcementId) !== String(announcementId)
          || String(existingJob.estateId) !== String(estateId)
          || existingJob.idempotencyKey !== idempotencyKey || !existingJob.jobId) {
          throw new AnnouncementScheduleError(
            'SCHEDULE_JOB_NOT_FOUND',
            'The scheduled delivery job could not be verified.',
          );
        }
        return Object.freeze({
          announcementId,
          estateId,
          status: AnnouncementStatus.SCHEDULED,
          scheduledAt: announcement.scheduledAt,
          timeZone,
          jobId: existingJob.jobId,
          replayed: true,
        });
      }
      const now = clock();
      const plan = planAnnouncementSchedule(announcement, {
        actorUserId,
        mayManageAnnouncements: true,
        sendAt,
        timeZone,
        now,
      });

      const scheduledAt = plan.effects[0].scheduledAt;
      const updated = await updateAnnouncementSchedule(tx, {
        announcementId,
        estateId,
        expectedStatus: AnnouncementStatus.DRAFT,
        expectedVersion: announcement.version ?? 1,
        status: AnnouncementStatus.SCHEDULED,
        scheduledAt,
        timeZone,
        actorUserId,
      });
      if (!updated || String(updated.id) !== String(announcementId)
        || String(updated.estateId) !== String(estateId)
        || updated.status !== AnnouncementStatus.SCHEDULED
        || updated.scheduledAt !== scheduledAt
        || updated.timeZone !== timeZone) {
        throw new AnnouncementScheduleError(
          'CONCURRENT_UPDATE',
          'The announcement changed before it could be scheduled. Reload and try again.',
        );
      }

      const job = await enqueueScheduledAnnouncement(tx, {
        announcementId,
        estateId,
        scheduledAt,
        idempotencyKey: plan.effects[1].idempotencyKey,
      });
      if (!job || String(job.announcementId) !== String(announcementId)
        || String(job.estateId) !== String(estateId)
        || job.idempotencyKey !== plan.effects[1].idempotencyKey
        || !job.jobId) {
        throw new AnnouncementScheduleError(
          'SCHEDULE_ENQUEUE_FAILED',
          'The scheduled delivery job could not be recorded.',
        );
      }

      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({
        announcementId,
        estateId,
        status: AnnouncementStatus.SCHEDULED,
        scheduledAt,
        timeZone,
        jobId: job.jobId,
        replayed: false,
      });
    }).catch((error) => {
      if (error instanceof AnnouncementScheduleError) throw error;
      if (error instanceof AnnouncementError) {
        throw new AnnouncementScheduleError(error.code, error.message);
      }
      throw error;
    });
  };
}

module.exports = { AnnouncementScheduleError, scheduleAnnouncementUseCase };
