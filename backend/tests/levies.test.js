const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { EstateChargesService } = require('../dist/src/properties/charges.service.js');

const hash = (value) => createHash('sha256').update(value, 'utf8').digest('hex');
const day = (value) => value.toISOString().slice(0, 10);
const decimal = (value) => ({ toString: () => value, toFixed: () => Number(value).toFixed(2) });

function makeFake() {
  const version = {
    id: 'version-1', chargeId: 'charge-1', versionNumber: 1, name: 'Monthly service levy',
    description: null, category: 'service_charge', amount: decimal('5000.00'), currency: 'NGN',
    recurrence: 'MONTHLY', effectiveFrom: new Date('2026-01-01T00:00:00.000Z'), effectiveTo: null,
    dueDay: 5, graceDays: 0, appliesTo: 'ESTATE', propertyId: null, propertyType: null,
    status: 'ACTIVE', charge: { code: 'SVC' },
  };
  const property = { id: 'property-1', code: 'PC-001', propertyType: 'Detached house' };
  const user = { id: 'user-1', emailNormalized: 'resident@test.example', displayName: 'Demo Resident' };
  const policy = {
    id: 'policy-1', estateId: 'estate', currency: 'NGN', bankName: 'Demo Bank',
    accountName: 'Demo Estate', accountNumber: '0123456789',
    paymentReferenceFormat: 'PAY-{{invoiceNumber}}', status: 'ACTIVE',
  };
  const drafts = new Map();
  const byIdem = new Map();
  const byTuple = new Map();
  const tuple = (row) => [row.estateId, row.chargeVersionId, row.propertyId, row.payerUserId, day(row.periodStart), day(row.periodEnd)].join('|');
  const asRecord = (data) => ({
    ...data,
    status: 'DRAFT',
    createdAt: new Date(),
    subtotal: decimal(data.subtotal.toString()),
    total: decimal(data.total.toString()),
  });

  const prisma = {
    estateMembership: { findFirst: async () => ({ id: 'membership-1' }) },
    estateSettlementPolicy: {
      findMany: async () => [{ currency: 'NGN' }],
      findFirst: async () => policy,
    },
    estateChargeVersion: {
      findMany: async () => [version],
      findFirst: async ({ where }) => (where.id === version.id ? version : null),
    },
    estateProperty: { findMany: async () => [property], findFirst: async () => property },
    propertyOccupancy: { findMany: async () => [{ residentId: user.id }], findFirst: async () => ({ id: 'occupancy-1' }) },
    estateTenancy: { findMany: async () => [], findFirst: async () => null },
    estateOwnershipInterest: { findMany: async () => [], findFirst: async () => null },
    user: { findMany: async () => [user], findFirst: async () => user },
    $queryRaw: async () => [],
    auditEvent: { create: async () => ({}) },
    estateInvoiceDraft: {
      findUnique: async ({ where }) => {
        if (where.createdById_estateId_idempotencyKeyHash) {
          return byIdem.get(where.createdById_estateId_idempotencyKeyHash.idempotencyKeyHash) ?? null;
        }
        if (where.estateId_chargeVersionId_propertyId_payerUserId_periodStart_periodEnd) {
          return byTuple.get(tuple(where.estateId_chargeVersionId_propertyId_payerUserId_periodStart_periodEnd)) ?? null;
        }
        return null;
      },
      findFirst: async ({ where }) => {
        if (where.id) {
          const record = drafts.get(where.id);
          return record ? { ...record, chargeVersion: { category: 'service_charge' } } : null;
        }
        return byTuple.get(tuple(where)) ?? null;
      },
      create: async ({ data }) => {
        const conflict = byTuple.get(tuple(data));
        if (conflict) throw Object.assign(new Error('duplicate'), { code: 'P2002' });
        const record = asRecord(data);
        drafts.set(record.id, record);
        byIdem.set(data.idempotencyKeyHash, record);
        byTuple.set(tuple(data), record);
        return record;
      },
      updateMany: async ({ where, data }) => {
        const record = drafts.get(where.id);
        if (!record) return { count: 0 };
        Object.assign(record, data);
        return { count: 1 };
      },
    },
    $transaction: async (callback) => callback(prisma),
  };
  return { prisma, drafts };
}

test('recurring levy generation is deterministic and idempotent', async () => {
  const { prisma, drafts } = makeFake();
  const service = new EstateChargesService(prisma);
  const first = await service.generateRecurring('actor', 'estate', { from: '2026-03-01', months: 2 });
  assert.equal(first.created, 2);
  assert.equal(first.issued, 2);
  assert.equal(first.failed, 0);
  const second = await service.generateRecurring('actor', 'estate', { from: '2026-03-01', months: 2 });
  assert.equal(second.created, 0);
  assert.equal(second.replayed, 2);
  assert.equal(second.alreadyIssued, 2);
  assert.equal(drafts.size, 2);
});

test('recurring preview computes correct calendar periods without writing', async () => {
  const { prisma } = makeFake();
  const service = new EstateChargesService(prisma);
  const preview = await service.previewRecurring('actor', 'estate', { from: '2026-03-10', months: 3 });
  const periods = preview.charges[0].periods;
  assert.deepEqual(periods.map((item) => `${item.start}/${item.end}`), [
    '2026-03-01/2026-03-31', '2026-04-01/2026-04-30', '2026-05-01/2026-05-31',
  ]);
  assert.equal(periods[0].recipients, 1);
});

test('charge applicability preview lists property and payer with reason', async () => {
  const { prisma } = makeFake();
  const service = new EstateChargesService(prisma);
  const preview = await service.previewApplicability('actor', 'estate', 'version-1', {
    periodStart: '2026-03-01', periodEnd: '2026-03-31',
  });
  assert.equal(preview.count, 1);
  assert.equal(preview.items[0].propertyCode, 'PC-001');
  assert.equal(preview.items[0].relationship, 'occupancy');
});

test('residents cannot generate recurring levies', async () => {
  const { prisma } = makeFake();
  prisma.estateMembership.findFirst = async () => null;
  const service = new EstateChargesService(prisma);
  await assert.rejects(
    service.generateRecurring('actor', 'estate', { from: '2026-03-01', months: 2 }),
    /charge management access/,
  );
});
