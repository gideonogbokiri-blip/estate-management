const test = require('node:test');
const assert = require('node:assert/strict');
const { Prisma } = require('../dist/src/generated/prisma/client.js');
const { ManagerResidentsService } = require('../dist/src/properties/manager-residents.service.js');

function fake(role = 'ESTATE_MANAGER') {
  const dec = (v) => new Prisma.Decimal(v);
  return {
    estateMembership: {
      findFirst: async ({ where }) => {
        if (where.role && where.role.in && !where.role.in.includes(role)) return null;
        return { status: 'ACTIVE' };
      },
      findMany: async () => [{ userId: 'r1', status: 'ACTIVE' }, { userId: 'r2', status: 'ACTIVE' }],
    },
    user: {
      findMany: async ({ where }) => {
        const ids = where.id?.in ?? where.id;
        if (!Array.isArray(ids)) return [];
        return ids.map((id) => ({
          id,
          displayName: id === 'l1' ? 'Landlord Adeyemi'
            : id === 'r1' ? 'Dr. Funke Adeyemi' : 'Other Resident',
          emailNormalized: `${id}@testlancon.com`,
        }));
      },
      findFirst: async () => ({ id: 'r1', displayName: 'Dr. Funke Adeyemi', emailNormalized: 'r1@testlancon.com' }),
    },
    propertyOccupancy: { findMany: async () => [
      { residentId: 'r1', propertyId: 'p1', relationship: 'TENANT', status: 'ACTIVE', effectiveFrom: new Date(), effectiveTo: null },
    ] },
    estateTenancy: { findMany: async () => [
      { tenantUserId: 'r1', payeeUserId: 'l1', propertyId: 'p1', status: 'ACTIVE', rentAmount: dec('50000'), currency: 'NGN', effectiveFrom: new Date(), effectiveTo: null },
    ] },
    estateOwnershipInterest: { findMany: async () => [] },
    estateProperty: { findMany: async () => [{ id: 'p1', code: 'A-104', unitNumber: 'Villa Lotus 12', propertyType: 'Detached house' }] },
    estateInvoiceDraft: { findMany: async () => [{
      id: 'i1', invoiceNumber: 'INV-1', status: 'ISSUED', total: dec('45000'), currency: 'NGN',
      dueDate: new Date('2025-03-31'), createdAt: new Date(),
      settlements: [{ amount: dec('5000'), receiptNumber: 'RCP-1' }],
    }] },
    estateWalletTransaction: { findMany: async () => [{
      id: 'w1', type: 'credit', amount: dec('125000'), currency: 'NGN',
      description: 'Escrow funding', reference: 'FUND-1', createdAt: new Date(),
    }] },
    rentPayment: { findMany: async () => [{
      id: 'rp1', amount: dec('50000'), currency: 'NGN', receiptNumber: 'RCP-RENT', receivedAt: new Date(),
    }] },
    estateServiceOrder: { findMany: async () => [{
      id: 's1', amount: dec('500'), currency: 'NGN', status: 'FULFILLED',
      provider: 'LANCON Services', fulfilmentCode: 'LAN-1', createdAt: new Date(),
    }] },
    householdMember: { findMany: async () => [] },
  };
}

test('manager resident directory links each resident to property and landlord', async () => {
  const service = new ManagerResidentsService(fake());
  const result = await service.listResidents('manager-1', 'estate-1');
  assert.equal(result.items.length, 2);
  const resident = result.items.find((item) => item.userId === 'r1');
  assert.equal(resident.name, 'Dr. Funke Adeyemi');
  assert.equal(resident.propertyCode, 'A-104');
  assert.equal(resident.landlordName, 'Landlord Adeyemi');
  assert.equal(resident.relationship, 'TENANT');
});

test('per-resident history returns only that resident records', async () => {
  const service = new ManagerResidentsService(fake());
  const result = await service.residentHistory('manager-1', 'estate-1', 'r1');
  assert.equal(result.resident.name, 'Dr. Funke Adeyemi');
  assert.equal(result.invoices[0].balance, '40000');
  assert.equal(result.wallet[0].amount, '125000');
  assert.equal(result.rent[0].receipt, 'RCP-RENT');
  assert.equal(result.services[0].provider, 'LANCON Services');
});

test('non-managers cannot read the resident directory', async () => {
  const service = new ManagerResidentsService(fake('RESIDENT'));
  await assert.rejects(service.listResidents('resident-1', 'estate-1'), /management access/);
});
