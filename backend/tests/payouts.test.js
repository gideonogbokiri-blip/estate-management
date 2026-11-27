const test = require('node:test');
const assert = require('node:assert/strict');
const { EstatePayoutService } = require('../dist/src/properties/payouts.service.js');

test('payout policy falls back to safe defaults', async () => {
  const prisma = {
    estateMembership: { findFirst: async () => ({ role: 'ESTATE_MANAGER' }) },
    estatePayoutPolicy: { findUnique: async () => null },
  };
  const service = new EstatePayoutService(prisma, {});
  const policy = await service.policy('actor', 'estate');
  assert.equal(policy.threshold.toString(), '100000');
  assert.equal(policy.requiredApprovals, 1);
});

test('residents cannot create payout beneficiaries', async () => {
  const prisma = {
    estateMembership: { findFirst: async () => ({ role: 'RESIDENT' }) },
  };
  const service = new EstatePayoutService(prisma, {});
  await assert.rejects(
    service.createBeneficiary('actor', 'estate', {
      displayName: 'Vendor', bankName: 'Bank', accountNumber: '0123456789', bankCode: '999',
    }),
    /Estate finance access is required/,
  );
});

test('only the estate chairman can decide payouts', async () => {
  const prisma = {
    estatePayoutRequest: {
      findUnique: async () => ({
        id: 'payout-1', estateId: 'estate-1', initiatedBy: 'manager-1',
        status: 'pending_approval', policySnapshot: { requiredApprovals: 1 },
      }),
    },
    estateMembership: { findFirst: async () => ({ role: 'ESTATE_ADMINISTRATOR' }) },
  };
  const service = new EstatePayoutService(prisma, {});
  await assert.rejects(
    service.approve('manager-1', 'payout-1', 'approve', ''),
    /Only the estate chairman can decide payouts/,
  );
});
