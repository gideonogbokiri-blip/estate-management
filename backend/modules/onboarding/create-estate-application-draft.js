const { ApplicationStatus } = require('./application-decision');

class EstateApplicationDraftCreationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationDraftCreationError';
    this.code = code;
  }
}

function createEstateApplicationDraftUseCase({ transaction, createDraftRecord, appendAuditEvent, clock = () => new Date() } = {}) {
  const requiredPorts = { transaction, createDraftRecord, appendAuditEvent };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new EstateApplicationDraftCreationError('MISSING_ADAPTER', `Draft creation adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new EstateApplicationDraftCreationError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function createEstateApplicationDraft({ actorUserId } = {}) {
    if (!actorUserId) {
      throw new EstateApplicationDraftCreationError('UNAUTHENTICATED', 'An authenticated applicant is required.');
    }

    return transaction(async (tx) => {
      const timestamp = new Date(clock());
      if (Number.isNaN(timestamp.getTime())) {
        throw new EstateApplicationDraftCreationError('INVALID_TIMESTAMP', 'A valid draft creation timestamp is required.');
      }
      const createdAt = timestamp.toISOString();
      const application = await createDraftRecord(tx, { applicantUserId: actorUserId, createdAt });
      if (!application?.id || application.applicantUserId !== actorUserId || application.status !== ApplicationStatus.DRAFT) {
        throw new EstateApplicationDraftCreationError('INVALID_DRAFT_RESULT', 'The repository must create a draft for the authenticated applicant.');
      }
      await appendAuditEvent(tx, {
        actorUserId,
        scope: 'platform',
        action: 'estate_application.draft_created',
        targetType: 'estate_application',
        targetId: application.id,
        outcome: 'success',
        occurredAt: createdAt,
      });
      return Object.freeze({ applicationId: application.id, status: application.status });
    });
  };
}

module.exports = { EstateApplicationDraftCreationError, createEstateApplicationDraftUseCase };

