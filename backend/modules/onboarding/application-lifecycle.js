const { ApplicationStatus } = require('./application-decision');

class ApplicationLifecycleError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ApplicationLifecycleError';
    this.code = code;
  }
}

const editableDraftFields = Object.freeze([
  'proposedName', 'estateType', 'address', 'state', 'lga', 'latitude', 'longitude',
  'applicantRelationship', 'applicantContactName', 'applicantContactEmail', 'applicantContactPhone',
  'managementEntityName', 'registrationNumber', 'homeCount', 'phaseCount', 'structureSummary',
]);
const textFieldLimits = Object.freeze({
  proposedName: 200,
  estateType: 80,
  address: 300,
  state: 100,
  lga: 100,
  applicantRelationship: 100,
  applicantContactName: 200,
  applicantContactEmail: 254,
  applicantContactPhone: 50,
  managementEntityName: 200,
  registrationNumber: 100,
  structureSummary: 500,
});

function validTimestamp(now) {
  return now !== undefined && now !== null && now !== '' && !Number.isNaN(new Date(now).getTime());
}

function missingRequiredFields(application, requiredFields) {
  if (!Array.isArray(requiredFields)) {
    throw new ApplicationLifecycleError('SUBMISSION_POLICY_REQUIRED', 'The server submission field policy is required.');
  }
  if (requiredFields.some((field) => typeof field !== 'string' || !editableDraftFields.includes(field))) {
    throw new ApplicationLifecycleError('INVALID_SUBMISSION_POLICY', 'Submission policy contains an unsupported field.');
  }
  return requiredFields.filter((field) => {
    const value = application[field];
    if (typeof value === 'string') return !value.trim();
    if (typeof value === 'number') return !Number.isFinite(value);
    if (typeof value === 'boolean') return false;
    if (Array.isArray(value)) return value.length === 0;
    if (value && typeof value === 'object') return Object.keys(value).length === 0;
    return value === undefined || value === null;
  });
}

/** Plan an applicant-owned partial draft update using the contract's canonical field names. */
function planApplicationDraftUpdate(application, { actorUserId, now, changes } = {}) {
  if (!application?.id || !application.applicantUserId || !application.status) {
    throw new ApplicationLifecycleError('INVALID_APPLICATION', 'A persisted application is required.');
  }
  if (!actorUserId || application.applicantUserId !== actorUserId) {
    throw new ApplicationLifecycleError('APPLICANT_SCOPE_DENIED', 'Only the application owner can edit it.');
  }
  if (![ApplicationStatus.DRAFT, ApplicationStatus.MORE_INFORMATION_REQUIRED].includes(application.status)) {
    throw new ApplicationLifecycleError('INVALID_STATE', 'Only a draft or returned application can be edited.');
  }
  if (!validTimestamp(now)) {
    throw new ApplicationLifecycleError('INVALID_TIMESTAMP', 'A valid update timestamp is required.');
  }
  if (!changes || typeof changes !== 'object' || Array.isArray(changes)) {
    throw new ApplicationLifecycleError('INVALID_CHANGES', 'Provide an application field update.');
  }

  const keys = Object.keys(changes);
  const unknownFields = keys.filter((field) => !editableDraftFields.includes(field));
  if (unknownFields.length) {
    throw new ApplicationLifecycleError('FIELD_NOT_EDITABLE', `These fields cannot be edited by the applicant: ${unknownFields.join(', ')}.`);
  }
  if (keys.length === 0) {
    throw new ApplicationLifecycleError('EMPTY_CHANGES', 'Provide at least one application field to update.');
  }

  const normalizedChanges = {};
  for (const field of keys) {
    const value = changes[field];
    const blank = value === null || value === '' || (typeof value === 'string' && !value.trim());
    if (['latitude', 'longitude'].includes(field)) {
      if (!blank && !Number.isFinite(Number(value))) {
        throw new ApplicationLifecycleError('INVALID_COORDINATE', `${field} must be a valid coordinate.`);
      }
      if (!blank && !['number', 'string'].includes(typeof value)) {
        throw new ApplicationLifecycleError('INVALID_COORDINATE', `${field} must be a valid coordinate.`);
      }
      normalizedChanges[field] = blank ? null : Number(value);
    } else if (['homeCount', 'phaseCount'].includes(field)) {
      if (blank && field === 'phaseCount') {
        normalizedChanges[field] = null;
      } else if (!['number', 'string'].includes(typeof value)
        || !Number.isInteger(Number(value)) || Number(value) < (field === 'homeCount' ? 1 : 0)) {
        throw new ApplicationLifecycleError('INVALID_STRUCTURE_COUNT', `${field} must be a valid non-negative whole number.`);
      } else {
        normalizedChanges[field] = Number(value);
      }
    } else if (value === null && ['registrationNumber', 'structureSummary'].includes(field)) {
      normalizedChanges[field] = null;
    } else if (typeof value !== 'string') {
      throw new ApplicationLifecycleError('INVALID_FIELD_VALUE', `${field} must be text.`);
    } else {
      const normalized = value.trim();
      if (normalized.length > textFieldLimits[field]) {
        throw new ApplicationLifecycleError('FIELD_TOO_LONG', `${field} exceeds its maximum length.`);
      }
      normalizedChanges[field] = normalized;
    }
  }

  const mergedLatitude = Object.prototype.hasOwnProperty.call(normalizedChanges, 'latitude') ? normalizedChanges.latitude : application.latitude;
  const mergedLongitude = Object.prototype.hasOwnProperty.call(normalizedChanges, 'longitude') ? normalizedChanges.longitude : application.longitude;
  if ((mergedLatitude === null || mergedLatitude === undefined) !== (mergedLongitude === null || mergedLongitude === undefined)) {
    throw new ApplicationLifecycleError('INCOMPLETE_COORDINATES', 'Enter both map coordinates or clear both.');
  }
  if (mergedLatitude !== null && mergedLatitude !== undefined
    && (mergedLatitude < -90 || mergedLatitude > 90 || mergedLongitude < -180 || mergedLongitude > 180)) {
    throw new ApplicationLifecycleError('INVALID_COORDINATE', 'Latitude or longitude is outside its valid range.');
  }

  const updatedAt = new Date(now).toISOString();
  return Object.freeze({
    transactionRequired: true,
    applicationId: application.id,
    changes: Object.freeze(normalizedChanges),
    effects: Object.freeze([Object.freeze({
      type: 'estate_application.draft_updated',
      applicationId: application.id,
      applicantUserId: actorUserId,
      changes: Object.freeze(normalizedChanges),
      updatedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'platform',
      action: 'estate_application.draft_updated',
      targetType: 'estate_application',
      targetId: application.id,
      outcome: 'success',
      occurredAt: updatedAt,
    }),
  });
}

/** Plan applicant submission/resubmission after trusted storage checks load verified document categories. */
function planApplicationSubmission(application, {
  actorUserId,
  now,
  requiredFields,
  requiredDocumentCategories,
  verifiedDocumentCategories,
} = {}) {
  if (!application?.id || !application.applicantUserId || !application.status) {
    throw new ApplicationLifecycleError('INVALID_APPLICATION', 'A persisted application is required.');
  }
  if (!actorUserId || application.applicantUserId !== actorUserId) {
    throw new ApplicationLifecycleError('APPLICANT_SCOPE_DENIED', 'Only the application owner can submit it.');
  }
  if (![ApplicationStatus.DRAFT, ApplicationStatus.MORE_INFORMATION_REQUIRED].includes(application.status)) {
    throw new ApplicationLifecycleError('INVALID_STATE', 'Only a draft or returned application can be submitted.');
  }
  if (!validTimestamp(now)) {
    throw new ApplicationLifecycleError('INVALID_TIMESTAMP', 'A valid submission timestamp is required.');
  }

  const missingFields = missingRequiredFields(application, requiredFields);
  if (missingFields.length) {
    throw new ApplicationLifecycleError('REQUIRED_FIELDS_MISSING', `Complete required fields: ${missingFields.join(', ')}.`);
  }
  if (!Array.isArray(requiredDocumentCategories) || !Array.isArray(verifiedDocumentCategories)) {
    throw new ApplicationLifecycleError('DOCUMENT_CHECK_REQUIRED', 'Load required and verified document categories from trusted services.');
  }
  const verified = new Set(verifiedDocumentCategories);
  const missingDocuments = requiredDocumentCategories.filter((category) => !verified.has(category));
  if (missingDocuments.length) {
    throw new ApplicationLifecycleError('REQUIRED_DOCUMENTS_MISSING', `Provide required documents: ${missingDocuments.join(', ')}.`);
  }

  const submittedAt = new Date(now).toISOString();
  return Object.freeze({
    transactionRequired: true,
    applicationId: application.id,
    nextStatus: ApplicationStatus.SUBMITTED,
    effects: Object.freeze([Object.freeze({
      type: 'estate_application.submitted',
      applicationId: application.id,
      applicantUserId: actorUserId,
      from: application.status,
      to: ApplicationStatus.SUBMITTED,
      submittedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'platform',
      action: 'estate_application.submit',
      targetType: 'estate_application',
      targetId: application.id,
      outcome: 'success',
      occurredAt: submittedAt,
    }),
  });
}

/** Plan reviewer assignment and transition into review after authorization and scoped row locking. */
function planApplicationReviewStart(application, { actorUserId, now } = {}) {
  if (!application?.id || !application.status) {
    throw new ApplicationLifecycleError('INVALID_APPLICATION', 'A persisted application is required.');
  }
  if (!actorUserId) {
    throw new ApplicationLifecycleError('MISSING_ACTOR', 'The authenticated reviewer is required.');
  }
  if (!validTimestamp(now)) {
    throw new ApplicationLifecycleError('INVALID_TIMESTAMP', 'A valid review timestamp is required.');
  }
  if (application.status !== ApplicationStatus.SUBMITTED) {
    throw new ApplicationLifecycleError('INVALID_STATE', 'Only a submitted application can enter review.');
  }
  if (application.assignedReviewerUserId && application.assignedReviewerUserId !== actorUserId) {
    throw new ApplicationLifecycleError('REVIEWER_SCOPE_DENIED', 'The application is assigned to another reviewer.');
  }

  const reviewedAt = new Date(now).toISOString();
  return Object.freeze({
    transactionRequired: true,
    applicationId: application.id,
    nextStatus: ApplicationStatus.UNDER_REVIEW,
    effects: Object.freeze([Object.freeze({
      type: 'estate_application.review_started',
      applicationId: application.id,
      reviewerUserId: actorUserId,
      from: application.status,
      to: ApplicationStatus.UNDER_REVIEW,
      reviewedAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'platform',
      action: 'estate_application.review_started',
      targetType: 'estate_application',
      targetId: application.id,
      outcome: 'success',
      occurredAt: reviewedAt,
    }),
  });
}

module.exports = {
  ApplicationLifecycleError,
  editableDraftFields,
  planApplicationDraftUpdate,
  planApplicationReviewStart,
  planApplicationSubmission,
};
