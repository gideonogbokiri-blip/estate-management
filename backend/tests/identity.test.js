const test = require('node:test');
const assert = require('node:assert/strict');
const { IdentityService } = require('../dist/src/properties/identity.service.js');

function fake() {
  let role = 'RESIDENT';
  const rows = [];
  const prisma = {
    estateMembership: { findFirst: async ({ where }) => {
      if (where.role?.in && !where.role.in.includes(role)) return null;
      return { role };
    } },
    identityVerification: {
      findFirst: async ({ where }) => rows.find((row) => Object.entries(where).every(([k, v]) => row[k] === v)) ?? null,
      findMany: async () => rows,
      create: async ({ data }) => {
        const row = { ...data, id: `identity-${rows.length + 1}`, submittedAt: new Date(), createdAt: new Date() };
        rows.push(row);
        return row;
      },
      update: async ({ where, data }) => {
        const row = rows.find((item) => item.id === where.id);
        Object.assign(row, data);
        return row;
      },
    },
    user: { findMany: async () => [{ id: 'resident-1', displayName: 'Demo Resident', emailNormalized: 'resident@test.example' }] },
    auditEvent: { create: async () => ({}) },
    $queryRaw: async () => [],
    $transaction: async (callback) => callback(prisma),
  };
  return { prisma, rows, setRole: (value) => { role = value; } };
}

const demoInput = {
  method: 'DEMO_DECLARATION', provider: 'LANCON Demo', level: 'BASIC', consentGiven: true,
};

test('consent is required to submit identity verification', async () => {
  const { prisma } = fake();
  const service = new IdentityService(prisma);
  await assert.rejects(
    service.submit('resident-1', 'estate-1', { ...demoInput, consentGiven: false }),
    /consent is required/,
  );
});

test('demo declaration gets a clearly labelled reference and stays pending', async () => {
  const { prisma, rows } = fake();
  const service = new IdentityService(prisma);
  const result = await service.submit('resident-1', 'estate-1', demoInput);
  assert.equal(result.status, 'pending');
  assert.equal(result.demo, true);
  assert.equal(result.providerReference.startsWith('DEMO-'), true);
  assert.equal(rows[0].status, 'PENDING');
});

test('provider token method requires a verification reference', async () => {
  const { prisma } = fake();
  const service = new IdentityService(prisma);
  await assert.rejects(
    service.submit('resident-1', 'estate-1', { ...demoInput, method: 'PROVIDER_TOKEN', provider: 'Demo Provider' }),
    /reference is required/,
  );
});

test('residents cannot decide and rejections require a reason', async () => {
  const { prisma, rows, setRole } = fake();
  const service = new IdentityService(prisma);
  await service.submit('resident-1', 'estate-1', demoInput);
  await assert.rejects(
    service.decide('resident-1', 'estate-1', rows[0].id, { decision: 'verify' }),
    /management access/,
  );
  setRole('ESTATE_MANAGER');
  await assert.rejects(
    service.decide('manager-1', 'estate-1', rows[0].id, { decision: 'reject' }),
    /reason is required/,
  );
  const verified = await service.decide('manager-1', 'estate-1', rows[0].id, { decision: 'verify' });
  assert.equal(verified.status, 'verified');
});
