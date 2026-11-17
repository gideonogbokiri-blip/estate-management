const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createVisitorCredential,
  hashVisitorCredential,
  credentialMatches,
  planPassVerification,
  planManualAdmission,
} = require('../modules/visitors/visitor-pass');
const { createGateVisitCheckInUseCase } = require('../modules/visitors/check-in-gate-visit');
const { createCurrentGateVisitorsUseCase } = require('../modules/visitors/list-current-gate-visitors');

const ACTOR = '11111111-1111-4111-8111-111111111111';
const ESTATE = '22222222-2222-4222-8222-222222222222';
const GATE = '33333333-3333-4333-8333-333333333333';
const PROPERTY = '44444444-4444-4444-8444-444444444444';
const VISIT = '55555555-5555-4555-8555-555555555555';
const KEY = 'test-request-key-0123456789abcdef0123456789abcdef';

test('visitor credentials are bounded, hashable and never stored in plain text', () => {
  const { credential, credentialHash } = createVisitorCredential();
  assert.match(credential, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(hashVisitorCredential(credential), credentialHash);
  assert.ok(credentialMatches(credential, credentialHash));
  assert.equal(hashVisitorCredential('short'), null);
  assert.equal(credentialMatches('short', credentialHash), false);
});

test('pass verification rejects expired, spent and revoked passes', () => {
  const now = new Date('2026-11-16T12:00:00.000Z').toISOString();
  const { credential, credentialHash } = createVisitorCredential();
  const gate = { id: GATE, estateId: ESTATE };
  const pass = {
    id: VISIT, estateId: ESTATE, credentialHash, visitorDisplayName: 'Test Visitor',
    validFrom: new Date(Date.parse(now) - 3600_000).toISOString(),
    validUntil: new Date(Date.parse(now) + 3600_000).toISOString(),
    allowedUses: 1, useCount: 0, revokedAt: null, propertyLabel: 'PC-001 · Unit 1',
    hostDisplayName: 'Test Host', vehicleSummary: null,
  };
  assert.equal(planPassVerification({ pass, credential, gate, now, activeVisit: null }).valid, true);
  assert.throws(() => planPassVerification({ pass: { ...pass, useCount: 1 }, credential, gate, now, activeVisit: null }), (error) => error.code === 'INVALID_CREDENTIAL');
  assert.throws(() => planPassVerification({ pass: { ...pass, revokedAt: now }, credential, gate, now, activeVisit: null }), (error) => error.code === 'INVALID_CREDENTIAL');
  assert.throws(() => planPassVerification({ pass: { ...pass, validUntil: new Date(Date.parse(now) - 1000).toISOString() }, credential, gate, now, activeVisit: null }), (error) => error.code === 'INVALID_CREDENTIAL');
  assert.throws(() => planPassVerification({ pass, credential: 'wrong', gate, now, activeVisit: null }), (error) => error.code === 'INVALID_CREDENTIAL');
});

test('manual admission produces passless visit and audited admission event', () => {
  const now = new Date('2026-11-16T12:00:00.000Z').toISOString();
  const plan = planManualAdmission({
    estateId: ESTATE,
    property: { id: PROPERTY, estateId: ESTATE, displayLabel: 'PC-001 · Unit 1' },
    gate: { id: GATE, estateId: ESTATE },
    staffUserId: ACTOR,
    visitId: VISIT,
    visitorDisplayName: 'Contractor',
    reason: 'Approved delivery access.',
    now,
  });
  const visitEffect = plan.effects.find((effect) => effect.type === 'visitor_visit.checked_in');
  const eventEffect = plan.effects.find((effect) => effect.type === 'access_event.append');
  assert.equal(visitEffect.passId, null);
  assert.equal(visitEffect.admissionType, 'manual');
  assert.equal(eventEffect.eventKind, 'manual_admission');
  assert.equal(plan.auditEvent.action, 'visitor.manual_admission');
});

function checkInPorts(overrides = {}) {
  const { credential } = createVisitorCredential();
  const now = new Date().toISOString();
  const pass = {
    id: VISIT, estateId: ESTATE, credentialHash: hashVisitorCredential(credential),
    visitorDisplayName: 'Test Visitor', propertyId: PROPERTY,
    validFrom: new Date(Date.parse(now) - 3600_000).toISOString(),
    validUntil: new Date(Date.parse(now) + 3600_000).toISOString(),
    allowedUses: 1, useCount: 0, revokedAt: null, propertyLabel: 'PC-001 · Unit 1',
    hostDisplayName: 'Test Host', vehicleSummary: null,
  };
  return {
    credential,
    ports: {
      transaction: async (work) => work({}),
      resolveAssignedGateAccess: async () => ({ actorUserId: ACTOR, estateId: ESTATE, gateId: GATE, gate: { id: GATE, estateId: ESTATE }, allowed: true }),
      enforceVerificationRateLimit: async () => true,
      findPassForVerificationUpdate: async () => pass,
      readCheckInIdempotency: async (_tx, scope) => null,
      claimCheckInIdempotency: async (_tx, scope) => ({ ...scope, id: 'claim-1', state: 'claimed' }),
      completeCheckInIdempotency: async (_tx, value) => ({ ...value.claim, state: 'completed', result: value.result }),
      findActiveVisitForPass: async (_tx, scope) => null,
      consumePassUse: async (_tx, value) => ({ id: pass.id, estateId: ESTATE, useCount: value.effect.newUseCount }),
      createCheckedInVisit: async (_tx, value) => ({
        id: value.effect.visitId, estateId: ESTATE, passId: pass.id, gateId: GATE,
        status: 'checked_in', checkedInAt: value.effect.checkedInAt, checkedInByUserId: ACTOR,
      }),
      appendAccessEvent: async (_tx, event) => ({}),
      appendAuditEvent: async (_tx, event) => ({}),
      generateVisitId: async (_tx, scope) => 'new-visit',
      ...overrides,
    },
  };
}

test('gate check-in rejects malformed request keys with INVALID_INPUT', async () => {
  const { ports, credential } = checkInPorts();
  const checkIn = createGateVisitCheckInUseCase(ports);
  await assert.rejects(
    checkIn({ actorUserId: ACTOR, estateId: ESTATE, gateId: GATE, credential, idempotencyKey: 'short', requestContext: { remoteAddress: 'test', userAgent: 'test' } }),
    (error) => error.code === 'INVALID_INPUT',
  );
});

test('gate check-in requires an assigned gate', async () => {
  const { ports, credential } = checkInPorts({
    resolveAssignedGateAccess: async () => ({ actorUserId: ACTOR, estateId: ESTATE, gateId: GATE, gate: null, allowed: false }),
  });
  const checkIn = createGateVisitCheckInUseCase(ports);
  await assert.rejects(
    checkIn({ actorUserId: ACTOR, estateId: ESTATE, gateId: GATE, credential, idempotencyKey: KEY, requestContext: { remoteAddress: 'test', userAgent: 'test' } }),
    (error) => error.code === 'GATE_ACCESS_DENIED',
  );
});

test('gate check-in commits when the adapter returns the planned timestamp', async () => {
  const { ports, credential } = checkInPorts();
  const checkIn = createGateVisitCheckInUseCase(ports);
  const result = await checkIn({ actorUserId: ACTOR, estateId: ESTATE, gateId: GATE, credential, idempotencyKey: KEY, requestContext: { remoteAddress: 'test', userAgent: 'test' } });
  assert.equal(result.status, 'checked_in');
  assert.equal(result.visitId, 'new-visit');
  assert.equal(result.visitorName, 'Test Visitor');
});

test('gate check-in catches adapters that return a Date instead of the planned ISO string', async () => {
  const { ports, credential } = checkInPorts({
    createCheckedInVisit: async (_tx, value) => ({
      id: value.effect.visitId, estateId: ESTATE, passId: VISIT, gateId: GATE,
      status: 'checked_in', checkedInAt: new Date(value.effect.checkedInAt), checkedInByUserId: ACTOR,
    }),
  });
  const checkIn = createGateVisitCheckInUseCase(ports);
  await assert.rejects(
    checkIn({ actorUserId: ACTOR, estateId: ESTATE, gateId: GATE, credential, idempotencyKey: KEY, requestContext: { remoteAddress: 'test', userAgent: 'test' } }),
    (error) => error.code === 'INVALID_COMMIT_RESULT',
  );
});

test('current gate visitors include passless manual admissions', async () => {
  const checkedInAt = new Date().toISOString();
  const visit = {
    id: VISIT, estateId: ESTATE, gateId: GATE, passId: null, propertyId: PROPERTY,
    admissionType: 'manual', visitorDisplayName: 'Contractor', status: 'checked_in', checkedInAt,
  };
  const list = createCurrentGateVisitorsUseCase({
    transaction: async (work) => work({}),
    resolveAssignedGateAccess: async () => ({ actorUserId: ACTOR, estateId: ESTATE, gateId: GATE, allowed: true }),
    queryCurrentGateVisits: async () => [{ ...visit }],
    loadPassForGateVisit: async () => { throw new Error('Manual visits have no pass.'); },
    projectCurrentGateVisitor: async ({ visit: current }) => ({
      visitId: current.id, estateId: current.estateId, gateId: current.gateId,
      propertyId: current.propertyId, visitorName: current.visitorDisplayName,
      propertyLabel: 'PC-001 · Unit 1', checkedInAt: current.checkedInAt,
    }),
  });
  const result = await list({ actorUserId: ACTOR, estateId: ESTATE, gateId: GATE });
  assert.equal(result.items.length, 1);
  assert.equal(result.items[0].visitorName, 'Contractor');
  assert.equal(result.items[0].hostDisplayName, 'Manual admission');
  assert.equal(result.items[0].vehicleSummary, null);
});
