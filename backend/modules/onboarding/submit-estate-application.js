const { planApplicationSubmission } = require('./application-lifecycle');

class EstateApplicationSubmissionError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'EstateApplicationSubmissionError';
    this.code = code;
  }
}

/** Submit or resubmit an applicant-owned application using trusted policy and document metadata. */
function createEstateApplicationSubmissionUseCase({
  transaction,
  findApplicantApplicationForUpdate,
  getSubmissionPolicy,
  findVerifiedDocumentCategories,
  commitSubmission,
  appendAuditEvent,
  clock = () => new Date(),
} = {}) {
  const requiredPorts = {
    transaction,
    findApplicantApplicationForUpdate,
    getSubmissionPolicy,
    findVerifiedDocumentCategories,
    commitSubmission,
    appendAuditEvent,
  };
  const missingPorts = Object.entries(requiredPorts).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missingPorts.length) {
    throw new EstateApplicationSubmissionError('MISSING_ADAPTER', `Submission adapters are required: ${missingPorts.join(', ')}.`);
  }
  if (typeof clock !== 'function') {
    throw new EstateApplicationSubmissionError('INVALID_CLOCK', 'A clock function is required.');
  }

  return async function submitEstateApplication({ actorUserId, applicationId } = {}) {
    if (!actorUserId || !applicationId) {
      throw new EstateApplicationSubmissionError('INVALID_SUBMISSION_INPUT', 'Applicant and application are required.');
    }

    return transaction(async (tx) => {
      // Applicant scoping and row locking prevent cross-user reads and duplicate concurrent submits.
      const application = await findApplicantApplicationForUpdate(tx, { applicationId, applicantUserId: actorUserId });
      if (!application) {
        throw new EstateApplicationSubmissionError('APPLICATION_NOT_FOUND', 'The application was not found.');
      }

      const policy = await getSubmissionPolicy(tx);
      const verifiedDocumentCategories = await findVerifiedDocumentCategories(tx, {
        applicationId,
        applicantUserId: actorUserId,
      });
      const plan = planApplicationSubmission(application, {
        actorUserId,
        now: clock(),
        requiredFields: policy?.requiredFields,
        requiredDocumentCategories: policy?.requiredDocumentCategories,
        verifiedDocumentCategories,
      });

      const result = await commitSubmission(tx, plan);
      await appendAuditEvent(tx, plan.auditEvent);
      return Object.freeze({ applicationId: plan.applicationId, status: plan.nextStatus, result });
    });
  };
}

module.exports = { EstateApplicationSubmissionError, createEstateApplicationSubmissionUseCase };
