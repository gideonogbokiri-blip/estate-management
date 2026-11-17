const TenancyStatus = Object.freeze({
  DRAFT: 'draft',
  PENDING_APPROVAL: 'pending_approval',
  ACTIVE: 'active',
  EXPIRING: 'expiring',
  EXPIRED: 'expired',
  TERMINATED: 'terminated',
  CANCELLED: 'cancelled',
});

const TenancyCommand = Object.freeze({ APPROVE: 'approve', TERMINATE: 'terminate', CANCEL: 'cancel' });
const RenewableTenancyStatuses = Object.freeze([TenancyStatus.ACTIVE, TenancyStatus.EXPIRING, TenancyStatus.EXPIRED]);
const CreatableTenancyStatuses = Object.freeze([TenancyStatus.DRAFT, TenancyStatus.PENDING_APPROVAL]);

class TenancyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'TenancyError';
    this.code = code;
  }
}

function isCalendarDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function isPresentId(value) {
  return (typeof value === 'string' && value.trim().length > 0)
    || (typeof value === 'number' && Number.isFinite(value));
}

function validateTenancyDraft(input) {
  const {
    estateId,
    propertyId,
    propertyEstateId,
    tenantUserId,
    payeeUserIds,
    rentAmount,
    currency,
    currencyScale,
    rentFrequency,
    startDate,
    endDate,
  } = input ?? {};

  if (![estateId, propertyId, tenantUserId].every(isPresentId) || propertyEstateId !== estateId) {
    throw new TenancyError('INVALID_TENANCY_RELATIONSHIP', 'Estate, same-estate property, and tenant are required.');
  }
  if (!Array.isArray(payeeUserIds) || payeeUserIds.length === 0
    || payeeUserIds.some((userId) => !isPresentId(userId))
    || new Set(payeeUserIds.map(String)).size !== payeeUserIds.length) {
    throw new TenancyError('INVALID_PAYEES', 'Link at least one unique landlord or authorized payee explicitly.');
  }
  if (typeof rentFrequency !== 'string' || !rentFrequency.trim()) {
    throw new TenancyError('INVALID_RENT_FREQUENCY', 'A configured rent frequency is required.');
  }
  if (!Number.isInteger(currencyScale) || currencyScale < 0 || currencyScale > 6) {
    throw new TenancyError('INVALID_CURRENCY_SCALE', 'Use the configured currency precision from the payment service.');
  }
  if (typeof rentAmount !== 'string' || !/^(?:0|[1-9]\d*)(?:\.\d+)?$/.test(rentAmount)) {
    throw new TenancyError('INVALID_RENT_AMOUNT', 'Rent must be supplied as a decimal string.');
  }
  const [whole, fraction = ''] = rentAmount.split('.');
  if (fraction.length > currencyScale) {
    throw new TenancyError('INVALID_RENT_PRECISION', 'Rent exceeds the configured currency precision.');
  }
  const normalizedAmount = currencyScale === 0
    ? whole
    : `${whole}.${fraction.padEnd(currencyScale, '0')}`;
  if (/^0(?:\.0+)?$/.test(normalizedAmount)) {
    throw new TenancyError('INVALID_RENT_AMOUNT', 'Rent must be greater than zero.');
  }
  if (typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) {
    throw new TenancyError('INVALID_CURRENCY', 'Currency must be a three-letter uppercase code.');
  }
  if (!isCalendarDate(startDate) || (endDate !== undefined && endDate !== null && !isCalendarDate(endDate))) {
    throw new TenancyError('INVALID_TENANCY_DATES', 'Tenancy dates must be valid YYYY-MM-DD calendar dates.');
  }
  if (endDate && endDate < startDate) {
    throw new TenancyError('INVALID_TENANCY_DATES', 'Tenancy end date cannot be before its start date.');
  }

  return Object.freeze({
    estateId,
    propertyId,
    tenantUserId,
    payeeUserIds: Object.freeze([...payeeUserIds]),
    rentAmount: normalizedAmount,
    currency,
    rentFrequency: rentFrequency.trim(),
    startDate,
    endDate: endDate || null,
  });
}

/** Plan initial tenancy creation from trusted estate/property policy and verified party links. */
function planTenancyCreation({ tenancyId, actorUserId, now, tenancyDraft, property, currencyScale, initialStatus } = {}) {
  if (!isPresentId(tenancyId) || !isPresentId(actorUserId)) {
    throw new TenancyError('INVALID_TENANCY_CREATION', 'A tenancy ID and authenticated actor are required.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new TenancyError('INVALID_TIMESTAMP', 'A valid tenancy creation timestamp is required.');
  }
  if (!property?.id || !property.estateId || tenancyDraft?.propertyId !== property.id
    || tenancyDraft?.estateId !== property.estateId) {
    throw new TenancyError('PROPERTY_SCOPE_MISMATCH', 'The property must belong to the selected estate.');
  }
  if (!CreatableTenancyStatuses.includes(initialStatus)) {
    throw new TenancyError('INVALID_INITIAL_STATUS', 'A new tenancy must start as a draft or pending approval.');
  }

  const terms = validateTenancyDraft({
    ...tenancyDraft,
    propertyEstateId: property.estateId,
    currencyScale,
  });
  const createdAt = new Date(now).toISOString();
  const tenancy = Object.freeze({
    id: tenancyId,
    ...terms,
    status: initialStatus,
    renewalOfTenancyId: null,
    createdByUserId: actorUserId,
    createdAt,
  });
  return Object.freeze({
    transactionRequired: true,
    tenancyId,
    estateId: terms.estateId,
    tenancy,
    effects: Object.freeze([Object.freeze({ type: 'tenancy.created', tenancy })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: terms.estateId,
      action: 'tenancy.created',
      targetType: 'tenancy',
      targetId: tenancyId,
      outcome: 'success',
      occurredAt: createdAt,
    }),
  });
}

/** Plan a terms edit only while a tenancy is still pre-activation. */
function planTenancyTermsUpdate(tenancy, { actorUserId, now, changes, property, currencyScale } = {}) {
  if (!tenancy || ![tenancy.id, tenancy.estateId, tenancy.propertyId, tenancy.tenantUserId].every(isPresentId)) {
    throw new TenancyError('INVALID_TENANCY', 'A persisted tenancy is required.');
  }
  if (!isPresentId(actorUserId)) throw new TenancyError('MISSING_ACTOR', 'The authenticated actor is required.');
  if (![TenancyStatus.DRAFT, TenancyStatus.PENDING_APPROVAL].includes(tenancy.status)) {
    throw new TenancyError('TERMS_LOCKED', 'Terms cannot be edited after tenancy activation.');
  }
  if (!property?.id || property.id !== tenancy.propertyId || property.estateId !== tenancy.estateId) {
    throw new TenancyError('PROPERTY_SCOPE_MISMATCH', 'The tenancy property must belong to the same estate.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new TenancyError('INVALID_TIMESTAMP', 'A valid terms-update timestamp is required.');
  }
  if (!changes || typeof changes !== 'object' || Array.isArray(changes)) {
    throw new TenancyError('INVALID_CHANGES', 'Provide tenancy term changes.');
  }
  const allowedFields = new Set(['payeeUserIds', 'rentAmount', 'rentFrequency', 'startDate', 'endDate']);
  const changedFields = Object.keys(changes);
  if (!changedFields.length || changedFields.some((field) => !allowedFields.has(field))) {
    throw new TenancyError('INVALID_CHANGES', 'Only payees, rent, frequency and term dates can be edited before activation.');
  }

  const merged = {
    estateId: tenancy.estateId,
    propertyId: tenancy.propertyId,
    tenantUserId: tenancy.tenantUserId,
    payeeUserIds: tenancy.payeeUserIds,
    rentAmount: tenancy.rentAmount,
    currency: tenancy.currency,
    rentFrequency: tenancy.rentFrequency,
    startDate: tenancy.startDate,
    endDate: tenancy.endDate,
    ...changes,
  };
  const nextTerms = validateTenancyDraft({
    ...merged,
    propertyEstateId: property.estateId,
    currencyScale,
  });
  const updatedAt = new Date(now).toISOString();
  const normalizedChanges = Object.freeze(Object.fromEntries(changedFields.map((field) => [field, nextTerms[field]])));
  const nextTenancy = Object.freeze({ ...tenancy, ...nextTerms, updatedAt, updatedByUserId: actorUserId });
  return Object.freeze({
    transactionRequired: true,
    tenancyId: tenancy.id,
    estateId: tenancy.estateId,
    nextTenancy,
    changedFields: Object.freeze([...changedFields]),
    changeRecord: Object.freeze({
      tenancyId: tenancy.id,
      estateId: tenancy.estateId,
      changedByUserId: actorUserId,
      changedAt: updatedAt,
      before: Object.freeze(Object.fromEntries(changedFields.map((field) => [field, tenancy[field]]))),
      after: normalizedChanges,
    }),
    effects: Object.freeze([Object.freeze({ type: 'tenancy.terms_updated', tenancyId: tenancy.id, changedFields: Object.freeze([...changedFields]), updatedAt })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: tenancy.estateId,
      action: 'tenancy.terms_updated',
      targetType: 'tenancy',
      targetId: tenancy.id,
      outcome: 'success',
      occurredAt: updatedAt,
      metadata: Object.freeze({ changedFields: Object.freeze([...changedFields]) }),
    }),
  });
}

/** Plan a new linked renewal record; the prior tenancy record is never modified. */
function planTenancyRenewal(previousTenancy, {
  actorUserId,
  now,
  renewalDraft,
  property,
  mayRenew,
  initialStatus,
} = {}) {
  if (!previousTenancy || ![previousTenancy.id, previousTenancy.estateId, previousTenancy.propertyId, previousTenancy.tenantUserId].every(isPresentId)) {
    throw new TenancyError('INVALID_TENANCY', 'A persisted prior tenancy is required.');
  }
  if (!actorUserId) {
    throw new TenancyError('MISSING_ACTOR', 'The authenticated actor is required.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new TenancyError('INVALID_TIMESTAMP', 'A valid renewal timestamp is required.');
  }
  if (!RenewableTenancyStatuses.includes(previousTenancy.status) || mayRenew !== true) {
    throw new TenancyError('RENEWAL_NOT_ALLOWED', 'The prior tenancy is not eligible for renewal under estate policy.');
  }
  if (!property?.id || property.id !== previousTenancy.propertyId || property.estateId !== previousTenancy.estateId) {
    throw new TenancyError('PROPERTY_SCOPE_MISMATCH', 'The renewal property must belong to the prior tenancy estate.');
  }
  if (![TenancyStatus.DRAFT, TenancyStatus.PENDING_APPROVAL].includes(initialStatus)) {
    throw new TenancyError('INVALID_RENEWAL_STATUS', 'A renewal must start as a draft or pending approval.');
  }

  const terms = validateTenancyDraft({
    ...renewalDraft,
    estateId: previousTenancy.estateId,
    propertyId: previousTenancy.propertyId,
    propertyEstateId: property.estateId,
  });
  if (terms.tenantUserId !== previousTenancy.tenantUserId) {
    throw new TenancyError('RENEWAL_TENANT_MISMATCH', 'A renewal must keep the prior tenancy tenant.');
  }

  const createdAt = new Date(now).toISOString();
  const renewal = Object.freeze({
    ...terms,
    status: initialStatus,
    renewalOfTenancyId: previousTenancy.id,
    createdByUserId: actorUserId,
    createdAt,
  });
  return Object.freeze({
    transactionRequired: true,
    priorTenancyId: previousTenancy.id,
    estateId: previousTenancy.estateId,
    renewal,
    effects: Object.freeze([Object.freeze({
      type: 'tenancy.renewal_created',
      priorTenancyId: previousTenancy.id,
      estateId: previousTenancy.estateId,
      propertyId: previousTenancy.propertyId,
      tenantUserId: previousTenancy.tenantUserId,
      renewal,
      actorUserId,
      occurredAt: createdAt,
    })]),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: previousTenancy.estateId,
      action: 'tenancy.renewal_created',
      targetType: 'tenancy',
      targetId: previousTenancy.id,
      outcome: 'success',
      occurredAt: createdAt,
      metadata: Object.freeze({ renewalOfTenancyId: previousTenancy.id }),
    }),
  });
}

/** Activate a linked renewal with a server-calculated, convention-aware handoff boundary. */
function planTenancyRenewalActivation(renewal, {
  previousTenancy,
  actorUserId,
  now,
  property,
  activeConflicts,
  renewalWindow,
} = {}) {
  if (!renewal || ![renewal.id, renewal.estateId, renewal.propertyId, renewal.tenantUserId].every(isPresentId)
    || !renewal.renewalOfTenancyId) {
    throw new TenancyError('INVALID_RENEWAL', 'A persisted linked renewal is required.');
  }
  if (!previousTenancy || previousTenancy.id !== renewal.renewalOfTenancyId
    || previousTenancy.estateId !== renewal.estateId
    || previousTenancy.propertyId !== renewal.propertyId
    || previousTenancy.tenantUserId !== renewal.tenantUserId
    || !RenewableTenancyStatuses.includes(previousTenancy.status)) {
    throw new TenancyError('INVALID_PRIOR_TENANCY', 'The linked prior tenancy must match the renewal estate, property and tenant.');
  }
  if (!actorUserId) {
    throw new TenancyError('MISSING_ACTOR', 'The authenticated actor is required.');
  }
  if (!validTimestamp(now)) {
    throw new TenancyError('INVALID_TIMESTAMP', 'A valid renewal activation timestamp is required.');
  }
  if (renewal.status !== TenancyStatus.PENDING_APPROVAL) {
    throw new TenancyError('INVALID_STATE', 'Only a pending renewal can be activated.');
  }
  if (!property?.id || property.id !== renewal.propertyId || property.estateId !== renewal.estateId) {
    throw new TenancyError('PROPERTY_SCOPE_MISMATCH', 'The renewal property must belong to the same estate.');
  }
  if (renewalWindow?.valid !== true) {
    throw new TenancyError('RENEWAL_DATE_POLICY_REQUIRED', 'The server date policy must verify the renewal handoff window.');
  }
  if (!Array.isArray(activeConflicts) || activeConflicts.some((conflict) =>
    conflict?.estateId !== renewal.estateId || conflict?.propertyId !== renewal.propertyId,
  )) {
    throw new TenancyError('CONFLICT_CHECK_REQUIRED', 'Load active tenancy conflicts scoped to this estate and property.');
  }
  if ([TenancyStatus.ACTIVE, TenancyStatus.EXPIRING].includes(previousTenancy.status)
    && !activeConflicts.some((conflict) => conflict?.id === previousTenancy.id)) {
    throw new TenancyError('CONFLICT_CHECK_REQUIRED', 'The active prior tenancy must be included in the conflict set.');
  }
  const competingTenancies = activeConflicts.filter((conflict) =>
    conflict?.id !== previousTenancy.id
    && conflict?.id !== renewal.id
    && [TenancyStatus.ACTIVE, TenancyStatus.EXPIRING].includes(conflict?.status),
  );
  if (competingTenancies.length) {
    throw new TenancyError('ACTIVE_TENANCY_CONFLICT', 'Another active tenancy conflicts with this renewal.');
  }

  const activatedAt = new Date(now).toISOString();
  const effects = [];
  if ([TenancyStatus.ACTIVE, TenancyStatus.EXPIRING].includes(previousTenancy.status)) {
    const previousOccupancyEnd = new Date(renewalWindow.previousOccupancyEndAt);
    if (Number.isNaN(previousOccupancyEnd.getTime())) {
      throw new TenancyError('RENEWAL_DATE_POLICY_REQUIRED', 'The date policy must provide a valid prior occupancy end instant.');
    }
    effects.push(
      {
        type: 'tenancy.status_changed',
        tenancyId: previousTenancy.id,
        estateId: previousTenancy.estateId,
        from: previousTenancy.status,
        to: TenancyStatus.EXPIRED,
        actorUserId,
        reason: 'Renewal activated',
        occurredAt: activatedAt,
      },
      {
        type: 'property_occupancy.end_from_tenancy',
        tenancyId: previousTenancy.id,
        estateId: previousTenancy.estateId,
        propertyId: previousTenancy.propertyId,
        userId: previousTenancy.tenantUserId,
        endedByUserId: actorUserId,
        endedAt: previousOccupancyEnd.toISOString(),
        recordedAt: activatedAt,
        reason: 'Renewal activated',
      },
    );
  }
  effects.push(
    {
      type: 'tenancy.status_changed',
      tenancyId: renewal.id,
      estateId: renewal.estateId,
      from: renewal.status,
      to: TenancyStatus.ACTIVE,
      actorUserId,
      reason: null,
      occurredAt: activatedAt,
    },
    {
      type: 'property_occupancy.create_from_tenancy',
      tenancyId: renewal.id,
      estateId: renewal.estateId,
      propertyId: renewal.propertyId,
      userId: renewal.tenantUserId,
      effectiveFrom: renewal.startDate,
      activatedByUserId: actorUserId,
      activatedAt,
    },
  );

  return Object.freeze({
    transactionRequired: true,
    tenancyId: renewal.id,
    priorTenancyId: previousTenancy.id,
    estateId: renewal.estateId,
    nextStatus: TenancyStatus.ACTIVE,
    effects: Object.freeze(effects.map(Object.freeze)),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: renewal.estateId,
      action: 'tenancy.renewal_activated',
      targetType: 'tenancy',
      targetId: renewal.id,
      outcome: 'success',
      occurredAt: activatedAt,
      metadata: Object.freeze({ priorTenancyId: previousTenancy.id }),
    }),
  });
}

function validTimestamp(value) {
  return value !== undefined && value !== null && value !== '' && !Number.isNaN(new Date(value).getTime());
}

function planTenancyCommand(tenancy, input) {
  if (!tenancy || ![tenancy.id, tenancy.estateId, tenancy.propertyId, tenancy.tenantUserId].every(isPresentId)) {
    throw new TenancyError('INVALID_TENANCY', 'A persisted tenancy is required.');
  }
  const { command, actorUserId, now, reason, property, activeConflicts, terminationDate, datePolicyAllowsTermination, activeOccupancy } = input ?? {};
  if (!actorUserId) {
    throw new TenancyError('MISSING_ACTOR', 'The authenticated actor is required.');
  }
  if (now === undefined || now === null || now === '' || Number.isNaN(new Date(now).getTime())) {
    throw new TenancyError('INVALID_TIMESTAMP', 'A valid transition timestamp is required.');
  }
  if (!Object.values(TenancyCommand).includes(command)) {
    throw new TenancyError('INVALID_COMMAND', 'Choose approve, terminate, or cancel.');
  }

  const normalizedReason = typeof reason === 'string' ? reason.trim() : '';
  const transitionedAt = new Date(now).toISOString();
  let nextStatus;
  const effects = [];

  if (command === TenancyCommand.APPROVE) {
    if (tenancy.status !== TenancyStatus.PENDING_APPROVAL) {
      throw new TenancyError('INVALID_STATE', 'Only a pending tenancy can be activated.');
    }
    if (!property?.id || property.id !== tenancy.propertyId || property.estateId !== tenancy.estateId) {
      throw new TenancyError('PROPERTY_SCOPE_MISMATCH', 'The tenancy property must belong to the same estate.');
    }
    if (!Array.isArray(activeConflicts)) {
      throw new TenancyError('CONFLICT_CHECK_REQUIRED', 'Check active property tenancies before activation.');
    }
    if (activeConflicts.some((conflict) =>
      conflict?.estateId !== tenancy.estateId || conflict?.propertyId !== tenancy.propertyId,
    )) {
      throw new TenancyError('CONFLICT_SCOPE_MISMATCH', 'The tenancy conflict query must be scoped to this property and estate.');
    }
    if (activeConflicts.some((conflict) =>
      conflict?.id !== tenancy.id
      && [TenancyStatus.ACTIVE, TenancyStatus.EXPIRING].includes(conflict?.status),
    )) {
      throw new TenancyError('ACTIVE_TENANCY_CONFLICT', 'The property already has an active tenancy.');
    }
    nextStatus = TenancyStatus.ACTIVE;
    effects.push({
      type: 'property_occupancy.create_from_tenancy',
      tenancyId: tenancy.id,
      estateId: tenancy.estateId,
      propertyId: tenancy.propertyId,
      userId: tenancy.tenantUserId,
      effectiveFrom: tenancy.startDate,
      activatedByUserId: actorUserId,
      activatedAt: transitionedAt,
    });
  } else if (command === TenancyCommand.TERMINATE) {
    if (![TenancyStatus.ACTIVE, TenancyStatus.EXPIRING].includes(tenancy.status)) {
      throw new TenancyError('INVALID_STATE', 'Only an active or expiring tenancy can be terminated.');
    }
    if (!normalizedReason) {
      throw new TenancyError('REASON_REQUIRED', 'A reason is required to terminate a tenancy.');
    }
    if (!isCalendarDate(terminationDate) || terminationDate < tenancy.startDate || datePolicyAllowsTermination !== true) {
      throw new TenancyError('INVALID_TERMINATION_DATE', 'The effective termination date must pass estate date policy and cannot precede the tenancy start.');
    }
    if (!activeOccupancy?.id || activeOccupancy.estateId !== tenancy.estateId
      || activeOccupancy.propertyId !== tenancy.propertyId || activeOccupancy.userId !== tenancy.tenantUserId
      || activeOccupancy.status !== 'active') {
      throw new TenancyError('ACTIVE_OCCUPANCY_REQUIRED', 'Load the active occupancy linked to this tenancy before termination.');
    }
    nextStatus = TenancyStatus.TERMINATED;
    effects.push({
      type: 'property_occupancy.end_from_tenancy',
      occupancyId: activeOccupancy.id,
      tenancyId: tenancy.id,
      estateId: tenancy.estateId,
      propertyId: tenancy.propertyId,
      userId: tenancy.tenantUserId,
      endedByUserId: actorUserId,
      effectiveTo: terminationDate,
      endedAt: transitionedAt,
      reason: normalizedReason,
    });
  } else {
    if (![TenancyStatus.DRAFT, TenancyStatus.PENDING_APPROVAL].includes(tenancy.status)) {
      throw new TenancyError('INVALID_STATE', 'Only a draft or pending tenancy can be cancelled.');
    }
    if (!normalizedReason) {
      throw new TenancyError('REASON_REQUIRED', 'A reason is required to cancel a tenancy.');
    }
    nextStatus = TenancyStatus.CANCELLED;
  }

  effects.unshift({
    type: 'tenancy.status_changed',
    tenancyId: tenancy.id,
    estateId: tenancy.estateId,
    from: tenancy.status,
    to: nextStatus,
    actorUserId,
    reason: normalizedReason || null,
    occurredAt: transitionedAt,
  });

  return Object.freeze({
    transactionRequired: true,
    tenancyId: tenancy.id,
    estateId: tenancy.estateId,
    nextStatus,
    effects: Object.freeze(effects.map(Object.freeze)),
    auditEvent: Object.freeze({
      actorUserId,
      scope: 'estate',
      estateId: tenancy.estateId,
      action: `tenancy.${command}`,
      targetType: 'tenancy',
      targetId: tenancy.id,
      outcome: 'success',
      reason: normalizedReason || null,
      occurredAt: transitionedAt,
    }),
  });
}

module.exports = {
  RenewableTenancyStatuses,
  CreatableTenancyStatuses,
  TenancyCommand,
  TenancyError,
  TenancyStatus,
  planTenancyCreation,
  planTenancyTermsUpdate,
  planTenancyCommand,
  planTenancyRenewal,
  planTenancyRenewalActivation,
  validateTenancyDraft,
};
