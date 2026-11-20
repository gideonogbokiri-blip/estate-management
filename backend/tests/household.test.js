const test = require('node:test');
const assert = require('node:assert/strict');
const { HouseholdService } = require('../dist/src/properties/household.service.js');

function fake() {
  const members = [];
  let role = 'RESIDENT';
  const users = [
    { id: 'resident-1', displayName: 'Demo Resident', emailNormalized: 'resident@test.example' },
    { id: 'manager-1', displayName: 'Demo Manager', emailNormalized: 'manager@test.example' },
  ];
  const matches = (row, where) => Object.entries(where).every(([key, value]) => {
    if (value && typeof value === 'object' && 'in' in value) return value.in.includes(row[key]);
    if (value && typeof value === 'object' && 'not' in value) return row[key] !== value.not;
    return row[key] === value;
  });
  const prisma = {
    estateMembership: { findFirst: async ({ where }) => {
      if (where.role?.in && !where.role.in.includes(role)) return null;
      return { role };
    } },
    estateProperty: {
      findFirst: async () => ({ id: 'property-1' }),
      findMany: async () => [{ id: 'property-1', code: 'PC-001', unitNumber: 'Unit 1' }],
    },
    estate: { findMany: async () => [{ id: 'estate-1', name: 'Demo Estate' }] },
    propertyOccupancy: { findFirst: async () => ({ id: 'occupancy-1' }) },
    estateTenancy: { findFirst: async () => null },
    estateOwnershipInterest: { findFirst: async () => null },
    user: { findMany: async ({ where }) => users.filter((user) => where.id.in.includes(user.id)) },
    householdMember: {
      findFirst: async ({ where }) => members.find((row) => matches(row, where)) ?? null,
      findUnique: async ({ where }) => members.find((row) => row.id === where.id) ?? null,
      create: async ({ data }) => {
        const row = { ...data, id: `member-${members.length + 1}`, createdAt: new Date() };
        members.push(row);
        return row;
      },
      update: async ({ where, data }) => {
        const row = members.find((item) => item.id === where.id);
        Object.assign(row, data);
        return row;
      },
    },
    auditEvent: { create: async () => ({}) },
    $queryRaw: async () => [],
    $transaction: async (callback) => callback(prisma),
  };
  return { prisma, members, setRole: (value) => { role = value; } };
}

const baseInput = {
  propertyId: 'property-1', fullName: 'Spouse One', relationship: 'SPOUSE', memberType: 'ADULT',
  effectiveFrom: '2026-01-01', financialAccess: true,
};

test('resident-added household member is pending and has no financial access', async () => {
  const { prisma, members } = fake();
  const service = new HouseholdService(prisma);
  const created = await service.add('resident-1', 'estate-1', { ...baseInput });
  assert.equal(created.status, 'pending_approval');
  assert.equal(created.financialAccess, false);
  assert.equal(members[0].status, 'PENDING_APPROVAL');
});

test('manager approval activates member but dependants never gain financial access', async () => {
  const { prisma, setRole } = fake();
  const service = new HouseholdService(prisma);
  setRole('ESTATE_MANAGER');
  const adult = await service.add('manager-1', 'estate-1', {
    ...baseInput, primaryUserId: 'resident-1', financialAccess: true,
  });
  assert.equal(adult.status, 'active');
  assert.equal(adult.financialAccess, true);
  const child = await service.add('manager-1', 'estate-1', {
    ...baseInput, primaryUserId: 'resident-1', fullName: 'Child One',
    relationship: 'CHILD', memberType: 'CHILD', financialAccess: true,
  });
  assert.equal(child.financialAccess, false);
});

test('residents cannot approve household members', async () => {
  const { prisma, members } = fake();
  const service = new HouseholdService(prisma);
  await service.add('resident-1', 'estate-1', { ...baseInput });
  await assert.rejects(
    service.decide('resident-1', 'estate-1', members[0].id, { decision: 'approve' }),
    /management access/,
  );
});

test('pending member can be approved by management', async () => {
  const { prisma, members, setRole } = fake();
  const service = new HouseholdService(prisma);
  await service.add('resident-1', 'estate-1', { ...baseInput });
  setRole('ESTATE_ADMINISTRATOR');
  const approved = await service.decide('manager-1', 'estate-1', members[0].id, { decision: 'approve', note: 'Checked IDs' });
  assert.equal(approved.status, 'active');
  assert.equal(approved.decisionReason, 'Checked IDs');
});
