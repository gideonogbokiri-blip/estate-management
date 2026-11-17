const { fromMinorUnits, toMinorUnits, validateScale } = require('../billing/money');

const DashboardSection = Object.freeze({
  PROPERTIES: 'properties',
  RESIDENTS: 'residents',
  TENANCIES: 'tenancies',
  FINANCE: 'finance',
  VISITORS: 'visitors',
  MAINTENANCE: 'maintenance',
});

const DashboardSectionStatus = Object.freeze(['available', 'incomplete', 'pending_reconciliation', 'unavailable']);
const FreshnessStatus = Object.freeze(['current', 'stale', 'delayed', 'unavailable']);
const DashboardCapabilities = Object.freeze({
  [DashboardSection.PROPERTIES]: Object.freeze(['property.view', 'report.operational.view']),
  [DashboardSection.RESIDENTS]: Object.freeze(['resident.view', 'report.resident.view']),
  [DashboardSection.TENANCIES]: Object.freeze(['tenancy.view', 'report.resident.view']),
  [DashboardSection.FINANCE]: Object.freeze(['report.financial.view']),
  [DashboardSection.VISITORS]: Object.freeze(['visitor.view', 'report.security.view']),
  [DashboardSection.MAINTENANCE]: Object.freeze(['maintenance.view', 'report.operational.view']),
});

class DashboardSummaryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'DashboardSummaryError';
    this.code = code;
  }
}

function validIsoTimestamp(value) {
  return typeof value === 'string' && value.includes('T') && !Number.isNaN(Date.parse(value))
    && Number.isFinite(Date.parse(value));
}

function requireCount(value, field) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new DashboardSummaryError('INVALID_SOURCE_DATA', `${field} must be a non-negative whole-number count.`);
  }
  return value;
}

function requireMoney(value, scale, field) {
  try {
    toMinorUnits(value, scale);
    return value;
  } catch {
    throw new DashboardSummaryError('INVALID_SOURCE_DATA', `${field} must be an exact decimal amount at the configured currency precision.`);
  }
}

function validateSectionData(section, data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    throw new DashboardSummaryError('INVALID_SOURCE_DATA', `The ${section} dashboard source is invalid.`);
  }
  if (section === DashboardSection.PROPERTIES) {
    const total = requireCount(data.totalProperties, 'totalProperties');
    const occupied = requireCount(data.occupiedProperties, 'occupiedProperties');
    const vacant = requireCount(data.vacantProperties, 'vacantProperties');
    if (occupied + vacant > total) throw new DashboardSummaryError('INVALID_SOURCE_DATA', 'Occupied and vacant properties cannot exceed the property total.');
    return Object.freeze({ totalProperties: total, occupiedProperties: occupied, vacantProperties: vacant });
  }
  if (section === DashboardSection.RESIDENTS) {
    return Object.freeze({
      totalRegisteredResidents: requireCount(data.totalRegisteredResidents, 'totalRegisteredResidents'),
      activeLandlords: requireCount(data.activeLandlords, 'activeLandlords'),
    });
  }
  if (section === DashboardSection.TENANCIES) {
    return Object.freeze({
      activeTenants: requireCount(data.activeTenants, 'activeTenants'),
      activeTenancies: requireCount(data.activeTenancies, 'activeTenancies'),
    });
  }
  if (section === DashboardSection.VISITORS) {
    return Object.freeze({
      activityCount: requireCount(data.activityCount, 'visitor.activityCount'),
      currentlyCheckedIn: requireCount(data.currentlyCheckedIn, 'visitor.currentlyCheckedIn'),
    });
  }
  if (section === DashboardSection.MAINTENANCE) {
    return Object.freeze({ openRequests: requireCount(data.openRequests, 'maintenance.openRequests') });
  }
  if (section === DashboardSection.FINANCE) {
    if (typeof data.currency !== 'string' || !/^[A-Z]{3}$/.test(data.currency)) {
      throw new DashboardSummaryError('INVALID_SOURCE_DATA', 'Finance dashboard data requires a configured three-letter currency code.');
    }
    try { validateScale(data.currencyScale); } catch {
      throw new DashboardSummaryError('INVALID_SOURCE_DATA', 'Finance dashboard data requires the configured currency precision.');
    }
    const streams = ['rent', 'estateFees', 'otherCharges'];
    const normalizedStreams = {};
    let totalCollectedMinor = 0n;
    for (const stream of streams) {
      const amounts = data[stream];
      if (!amounts || typeof amounts !== 'object' || Array.isArray(amounts)) {
        throw new DashboardSummaryError('INVALID_SOURCE_DATA', `Finance dashboard data is missing the ${stream} totals.`);
      }
      const billed = requireMoney(amounts.billed, data.currencyScale, `${stream}.billed`);
      const collected = requireMoney(amounts.collected, data.currencyScale, `${stream}.collected`);
      const outstanding = requireMoney(amounts.outstanding, data.currencyScale, `${stream}.outstanding`);
      normalizedStreams[stream] = Object.freeze({ billed, collected, outstanding });
      totalCollectedMinor += toMinorUnits(collected, data.currencyScale);
    }
    const expensesPaid = requireMoney(data.expensesPaid, data.currencyScale, 'expensesPaid');
    const operatingPositionMinor = totalCollectedMinor - toMinorUnits(expensesPaid, data.currencyScale);
    return Object.freeze({
      currency: data.currency,
      currencyScale: data.currencyScale,
      rent: normalizedStreams.rent,
      estateFees: normalizedStreams.estateFees,
      otherCharges: normalizedStreams.otherCharges,
      expensesPaid,
      netOperatingPosition: fromMinorUnits(operatingPositionMinor, data.currencyScale),
    });
  }
  throw new DashboardSummaryError('INVALID_SECTION', `Unsupported dashboard section ${section}.`);
}

function validatePeriod(period, estateTimeZone) {
  if (!period || !validIsoTimestamp(period.startAt) || !validIsoTimestamp(period.endAt)
    || Date.parse(period.endAt) <= Date.parse(period.startAt)) {
    throw new DashboardSummaryError('INVALID_PERIOD', 'The dashboard period must have ordered ISO start and end timestamps.');
  }
  if (period.timeZone !== estateTimeZone) {
    throw new DashboardSummaryError('INVALID_PERIOD', 'The dashboard period must use the estate reporting timezone.');
  }
  const durationDays = (Date.parse(period.endAt) - Date.parse(period.startAt)) / 86_400_000;
  if (durationDays > 366) throw new DashboardSummaryError('INVALID_PERIOD', 'Dashboard summary periods cannot exceed 366 days.');
  try { new Intl.DateTimeFormat('en-US', { timeZone: estateTimeZone }).format(new Date(period.startAt)); } catch {
    throw new DashboardSummaryError('INVALID_TIMEZONE', 'The estate reporting timezone is invalid.');
  }
  return Object.freeze({ startAt: period.startAt, endAt: period.endAt, timeZone: estateTimeZone });
}

/** Load capability-filtered, source-backed dashboard metrics under one authorized estate snapshot. */
function createDashboardSummaryUseCase({
  transaction,
  resolveDashboardReportAccess,
  resolveDashboardPeriod,
  loadDashboardFacts,
  clock = () => new Date(),
} = {}) {
  const ports = { transaction, resolveDashboardReportAccess, resolveDashboardPeriod, loadDashboardFacts };
  const missing = Object.entries(ports).filter(([, port]) => typeof port !== 'function').map(([name]) => name);
  if (missing.length) throw new DashboardSummaryError('MISSING_ADAPTER', `Dashboard summary adapters are required: ${missing.join(', ')}.`);
  if (typeof clock !== 'function') throw new DashboardSummaryError('INVALID_CLOCK', 'A dashboard clock function is required.');

  return async function readDashboardSummary({ actorUserId, estateId, requestedPeriod } = {}) {
    if (!actorUserId || !estateId) throw new DashboardSummaryError('INVALID_INPUT', 'Authenticated actor and estate context are required.');
    return transaction(async (tx) => {
      const access = await resolveDashboardReportAccess(tx, { actorUserId, estateId });
      if (!access || String(access.actorUserId) !== String(actorUserId) || String(access.estateId) !== String(estateId)) {
        throw new DashboardSummaryError('ESTATE_ACCESS_DENIED', 'The actor has no authorized dashboard context for this estate.');
      }
      if (typeof access.timeZone !== 'string' || !access.timeZone.trim()) {
        throw new DashboardSummaryError('INVALID_ACCESS_CONTEXT', 'The estate reporting timezone is required.');
      }
      const timeZone = access.timeZone.trim();
      if (!Array.isArray(access.permissions)) throw new DashboardSummaryError('INVALID_ACCESS_CONTEXT', 'Effective estate capabilities must be a list.');
      const permissions = new Set();
      for (const capability of access.permissions) {
        if (typeof capability !== 'string' || !capability.trim() || capability.trim().length > 120
          || capability.trim().startsWith('platform.')) {
          throw new DashboardSummaryError('INVALID_ACCESS_CONTEXT', 'Dashboard access cannot use malformed or platform capabilities.');
        }
        permissions.add(capability.trim());
      }
      const sections = Object.keys(DashboardCapabilities).filter((section) =>
        DashboardCapabilities[section].some((capability) => permissions.has(capability)),
      );
      if (!sections.length) throw new DashboardSummaryError('REPORT_ACCESS_DENIED', 'The actor has no capability to view estate dashboard metrics.');
      const period = validatePeriod(
        await resolveDashboardPeriod(tx, { estateId, timeZone, requestedPeriod, now: clock() }),
        timeZone,
      );
      const facts = await loadDashboardFacts(tx, {
        estateId,
        period,
        sections: Object.freeze(sections),
      });
      if (!facts || typeof facts !== 'object' || Array.isArray(facts)
        || String(facts.estateId) !== String(estateId)
        || !facts.sections || typeof facts.sections !== 'object'
        || !facts.sourceFreshness || typeof facts.sourceFreshness !== 'object') {
        throw new DashboardSummaryError('INVALID_SOURCE_DATA', 'The dashboard adapter must return scoped metrics and source freshness.');
      }
      if (Object.keys(facts.sections).some((section) => !sections.includes(section))
        || Object.keys(facts.sourceFreshness).some((section) => !sections.includes(section))) {
        throw new DashboardSummaryError('UNAUTHORIZED_SOURCE_DATA', 'The dashboard adapter returned a section outside the actor capability scope.');
      }
      const normalizedSections = {};
      const sourceFreshness = {};
      for (const section of sections) {
        const source = facts.sections[section];
        const freshness = facts.sourceFreshness[section];
        if (!source || !DashboardSectionStatus.includes(source.status)
          || !freshness || !FreshnessStatus.includes(freshness.status)
          || (freshness.sourceAsOf !== null && freshness.sourceAsOf !== undefined && !validIsoTimestamp(freshness.sourceAsOf))
          || (freshness.status !== 'unavailable' && !validIsoTimestamp(freshness.sourceAsOf))) {
          throw new DashboardSummaryError('INVALID_SOURCE_DATA', `The ${section} dashboard source status is invalid.`);
        }
        sourceFreshness[section] = Object.freeze({
          status: freshness.status,
          sourceAsOf: freshness.sourceAsOf || null,
        });
        normalizedSections[section] = source.status === 'unavailable'
          ? Object.freeze({ status: source.status })
          : Object.freeze({ status: source.status, ...validateSectionData(section, source.data) });
      }
      const asOf = new Date(clock());
      if (Number.isNaN(asOf.getTime())) throw new DashboardSummaryError('INVALID_CLOCK', 'The dashboard clock returned an invalid time.');
      return Object.freeze({
        estateId,
        asOf: asOf.toISOString(),
        period,
        sections: Object.freeze(normalizedSections),
        sourceFreshness: Object.freeze(sourceFreshness),
      });
    });
  };
}

module.exports = {
  DashboardCapabilities,
  DashboardSection,
  DashboardSectionStatus,
  DashboardSummaryError,
  FreshnessStatus,
  createDashboardSummaryUseCase,
  validatePeriod,
  validateSectionData,
};
