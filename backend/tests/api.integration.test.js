const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');

const BASE = process.env.API_BASE_URL ?? 'http://127.0.0.1:4100/api/v1';
const runIntegration = process.env.RUN_API_INTEGRATION === '1';
const OFFICER_EMAIL = process.env.GATE_DEMO_EMAIL ?? 'estate.security.demo@example.test';
const OFFICER_PASSWORD = process.env.GATE_DEMO_PASSWORD ?? 'Demo-Gate-6Qm2-Vr8w';
const PASS_CODE = process.env.GATE_DEMO_PASS_CODE ?? 'oyRM7SDk4jrM4pQphR7hBThqgqKZyl1X-Spjd7FXAkQ';

async function request(method, path, { token, body, headers } = {}) {
  const response = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers ?? {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { json = { raw: text }; }
  return { status: response.status, json };
}

test('live gate API workflow', { skip: !runIntegration && 'set RUN_API_INTEGRATION=1 to run against a local API' }, async () => {
  const login = await request('POST', '/auth/login', { body: { email: OFFICER_EMAIL, password: OFFICER_PASSWORD } });
  assert.equal(login.status, 200);
  const token = login.json.accessToken;
  assert.ok(token);

  const estates = await request('GET', '/estate/estates/mine', { token });
  const estate = estates.json.items.find((item) => (item.roles ?? []).includes('security_officer'));
  assert.ok(estate, 'security officer membership is required');

  const gates = await request('GET', `/estate/security/gates?estateId=${estate.id}`, { token });
  const gate = gates.json.items[0];
  assert.ok(gate, 'an assigned gate is required');

  const expected = await request('GET', `/estate/security/gates/${gate.id}/visitors/expected?estateId=${estate.id}`, { token });
  assert.equal(expected.status, 200);
  assert.ok(expected.json.items.length > 0);

  const contacts = await request('GET', `/estate/estates/${estate.id}/security/contacts`, { token });
  assert.equal(contacts.status, 200);
  assert.ok(contacts.json.items.length > 0);

  const checkIn = await request('POST', `/estate/security/gates/${gate.id}/check-in?estateId=${estate.id}`, {
    token,
    headers: { 'Idempotency-Key': `integration-check-in-${randomUUID()}` },
    body: { credential: PASS_CODE },
  });
  assert.equal(checkIn.status, 201, JSON.stringify(checkIn.json));

  const current = await request('GET', `/estate/security/gates/${gate.id}/visitors/current?estateId=${estate.id}`, { token });
  const visit = current.json.items.find((item) => item.visitId === checkIn.json.visitId);
  assert.ok(visit, 'the checked-in visitor must be visible at the gate');

  const checkOut = await request('POST', `/estate/security/gates/${gate.id}/visits/${visit.visitId}/check-out?estateId=${estate.id}`, { token, body: {} });
  assert.equal(checkOut.status, 201);

  const manual = await request('POST', `/estate/security/gates/${gate.id}/manual-admissions?estateId=${estate.id}`, {
    token,
    headers: { 'Idempotency-Key': `integration-manual-${randomUUID()}` },
    body: { visitorDisplayName: 'Automated Test Visitor', propertyReference: 'PC-001', reason: 'Automated integration test of the manual admission path.' },
  });
  assert.equal(manual.status, 201, JSON.stringify(manual.json));
  assert.equal(manual.json.visitorName, 'Automated Test Visitor');

  const events = await request('GET', `/estate/estates/${estate.id}/security/access-events?eventKind=manual_admission&pageSize=10`, { token });
  assert.equal(events.status, 200);
  assert.ok(events.json.items.some((event) => event.visitId === manual.json.visitId));

  const manualCheckOut = await request('POST', `/estate/security/gates/${gate.id}/visits/${manual.json.visitId}/check-out?estateId=${estate.id}`, { token, body: {} });
  assert.equal(manualCheckOut.status, 201);

  const incident = await request('POST', `/estate/estates/${estate.id}/security-incidents`, {
    token,
    body: {
      category: 'safety',
      priority: 'normal',
      description: 'Automated integration test report; no emergency response is implied.',
      observedAt: new Date(Date.now() - 60_000).toISOString(),
    },
  });
  assert.equal(incident.status, 201);

  const mine = await request('GET', `/estate/estates/${estate.id}/security-incidents/mine`, { token });
  assert.equal(mine.status, 200);
  assert.ok(mine.json.items.some((item) => item.reference === incident.json.reference));

  const anonymous = await request('GET', `/estate/security/gates?estateId=${estate.id}`);
  assert.equal(anonymous.status, 401);
});
