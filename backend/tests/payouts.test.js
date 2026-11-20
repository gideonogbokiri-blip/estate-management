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
