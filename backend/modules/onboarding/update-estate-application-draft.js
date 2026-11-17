const { planApplicationDraftUpdate } = require('./application-lifecycle');

class EstateApplicationDraftUpdateError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationDraftUpdateError';
    this.code = code;
  }
}

function createEstateApplicationDraftUpdateUseCase({
  transaction,
  findApplicantApplicationForUpdate,
  commitDraftUpdate,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = { transaction, findApplicantApplicationForUpdate, commitDraftUpdate, appendAuditEvent };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new EstateApplicationDraftUpdateError('MISSING_ADAPTER', `Draft update adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new EstateApplicationDraftUpdateError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function updateEstateApplicationDraft({ actorUserId, applicationId, changes } = {}) {
    if (!actorUserId || !applicationId) {
      throw new EstateApplicationDraftUpdateError('INVALID_UPDATE_INPUT', 'Applicant and application are required.');
    }

    return transaction(async (tx) => {
      const application = await findApplicantApplicationForUpdate(tx, { applicationId, applicantUserId: actorUserId });
      if (!application) {
        throw new EstateApplicationDraftUpdateError('APPLICATION_NOT_FOUND', 'The application was not found.');
      }

      const plan = planApplicationDraftUpdate(application, { actorUserId, now: clock(), changes });
      const result = await commitDraftUpdate(tx, plan);
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ applicationId: plan.applicationId, result });
    });
  };
}

module.exports = { EstateApplicationDraftUpdateError, createEstateApplicationDraftUpdateUseCase };
