const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');

const BASE = process.env.API_BASE_URL ?? 'http://127.0.0.1:4100/api/v1';
const run = process.env.RUN_API_INTEGRATION === '1';

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

async function login(email, password) {
  const response = await request('POST', '/auth/login', { body: { email, password } });
  assert.equal(response.status, 200);
  return response.json.accessToken;
}

test('platform balance adjustments are authorized, audited and net correctly',
  { skip: !run && 'set RUN_API_INTEGRATION=1 to run against a local API' },
  async () => {
    const platform = await login(
      process.env.PLATFORM_DEMO_EMAIL ?? 'estate.platform.demo@example.test',
      process.env.PLATFORM_DEMO_PASSWORD ?? 'Demo-Review-7Kp4-nQ8v',
    );
    const manager = await login(
      process.env.MANAGER_DEMO_EMAIL ?? 'estate.manager.demo@example.test',
      process.env.MANAGER_DEMO_PASSWORD ?? 'Demo-kYCMk-QoRFM0htEs',
    );
    const managerEstates = await request('GET', '/estate/estates/mine', { token: manager });
    const estateId = managerEstates.json.items[0].id;

    const overview = await request('GET', '/platform/admin/money/overview', { token: platform });
    assert.equal(overview.status, 200);
    assert.ok(overview.json.estates.total >= 1);

    const accounts = await request('GET', `/platform/admin/money/estates/${estateId}/accounts?pageSize=100`, { token: platform });
    assert.equal(accounts.status, 200);
    const resident = accounts.json.items.find((item) => item.accountRole === 'RESIDENT');
    assert.ok(resident, 'the seeded estate needs a resident account');

    const key = `integration-balance-${randomUUID()}`;
    const credit = await request('POST', `/platform/admin/money/estates/${estateId}/accounts/${resident.userId}/adjustments`, {
      token: platform,
      headers: { 'Idempotency-Key': key },
      body: { amount: '100.00', currency: 'NGN', direction: 'credit', reason: 'Automated integration test credit.' },
    });
    assert.equal(credit.status, 201, JSON.stringify(credit.json));

    const replay = await request('POST', `/platform/admin/money/estates/${estateId}/accounts/${resident.userId}/adjustments`, {
      token: platform,
      headers: { 'Idempotency-Key': key },
      body: { amount: '100.00', currency: 'NGN', direction: 'credit', reason: 'Automated integration test credit.' },
    });
    assert.equal(replay.status, 201);
    assert.equal(replay.json.id, credit.json.id);
    assert.equal(replay.json.replayed, true);

    const history = await request('GET', `/platform/admin/money/estates/${estateId}/accounts/${resident.userId}/adjustments`, { token: platform });
    assert.equal(history.status, 200);
    assert.ok(history.json.items.some((item) => item.id === credit.json.id));

    const denied = await request('GET', '/platform/admin/money/overview', { token: manager });
    assert.equal(denied.status, 403);
  },
);
