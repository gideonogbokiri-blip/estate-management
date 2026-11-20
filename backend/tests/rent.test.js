const test = require('node:test');
const assert = require('node:assert/strict');
const { RentService } = require('../dist/src/properties/rent.service.js');

function fakePrisma() {
  const created = [];
  const byKey = new Map();
  const prisma = {
    estateMembership: { findFirst: async () => ({ role: 'ESTATE_MANAGER' }) },
    estateTenancy: { findMany: async () => [{
      id: 'tenancy-1', tenantUserId: 'tenant-1', payeeUserId: 'landlord-1',
      propertyId: 'property-1', rentAmount: { toString: () => '50000' },
      currency: 'NGN', rentFrequency: 'MONTHLY', rentDueDay: 1,
      effectiveFrom: new Date('2026-01-01T00:00:00.000Z'), effectiveTo: null,
    }] },
    rentSchedule: {
      findUnique: async ({ where }) => byKey.get(where.idempotencyKey) ?? null,
      create: async ({ data }) => {
        created.push(data);
        const row = { id: `schedule-${created.length}` };
        byKey.set(data.idempotencyKey, row);
        return row;
      },
    },
    auditEvent: { create: async () => ({}) },
  };
  return { prisma, created };
}

test('rent generation is deterministic and idempotent', async () => {
  const { prisma, created } = fakePrisma();
  const service = new RentService(prisma);
  const from = '2026-03-01';
  const first = await service.generate('actor', 'estate', from, 3);
  assert.equal(first.created, 3);
  assert.equal(first.skipped, 0);
  const keys = created.map((row) => row.idempotencyKey);
  assert.deepEqual(keys, [
    'tenancy-1:2026-03-01', 'tenancy-1:2026-04-01', 'tenancy-1:2026-05-01',
  ]);
  const second = await service.generate('actor', 'estate', from, 3);
  assert.equal(second.created, 0);
  assert.equal(second.skipped, 3);
  assert.equal(created.length, 3);
});

test('residents cannot generate rent schedules', async () => {
  const { prisma } = fakePrisma();
  prisma.estateMembership.findFirst = async () => ({ role: 'RESIDENT' });
  const service = new RentService(prisma);
  await assert.rejects(service.generate('actor', 'estate', '2026-03-01', 3), /Estate finance access/);
});
