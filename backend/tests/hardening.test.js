const test = require('node:test');
const assert = require('node:assert/strict');
const { Prisma } = require('../dist/src/generated/prisma/client.js');
const { ReportsService } = require('../dist/src/properties/reports.service.js');
const { RateLimitGuard } = require('../dist/src/security/rate-limit.guard.js');

function reportsFake(role = 'RESIDENT') {
  const wallets = [
    { id: 'wallet-1', userId: 'resident-1', currency: 'NGN', accountNumber: 'DEMO-1', status: 'active' },
    { id: 'wallet-2', userId: 'resident-2', currency: 'NGN', accountNumber: 'DEMO-2', status: 'active' },
  ];
  const transactions = [
    { id: 'tx-1', walletId: 'wallet-1', type: 'credit', amount: new Prisma.Decimal('100.00'), currency: 'NGN', reference: 'FUND-1', description: 'Demo funding', sourceType: 'demo_funding', createdAt: new Date('2026-03-01T00:00:00Z') },
    { id: 'tx-2', walletId: 'wallet-1', type: 'debit', amount: new Prisma.Decimal('30.00'), currency: 'NGN', reference: 'RENT-1', description: 'Rent', sourceType: 'rent_payment', createdAt: new Date('2026-03-02T00:00:00Z') },
  ];
  const prisma = {
    estateMembership: { findFirst: async ({ where }) => {
      if (where.role?.in && !where.role.in.includes(role)) return null;
      return { role };
    } },
    estateWallet: { findMany: async ({ where }) => wallets.filter((wallet) => {
      if (where.userId && wallet.userId !== where.userId) return false;
      return true;
    }) },
    estateWalletTransaction: {
      findMany: async ({ where }) => transactions.filter((tx) => {
        if (where.walletId?.in && !where.walletId.in.includes(tx.walletId)) return false;
        if (where.createdAt?.lt && tx.createdAt >= where.createdAt.lt) return false;
        return true;
      }),
    },
    auditEvent: { findMany: async () => [] },
    ledgerJournal: { findMany: async () => [] },
  };
  return { prisma, wallets, transactions };
}

test('wallet statement computes running balances and is scoped to the account holder', async () => {
  const { prisma } = reportsFake('RESIDENT');
  const service = new ReportsService(prisma);
  const statement = await service.walletStatement('resident-1', 'estate-1', {});
  assert.equal(statement.items.length, 2);
  assert.equal(statement.items[0].balance, '100');
  assert.equal(statement.items[1].balance, '70');
  assert.equal(statement.summary.closing, '70');
});

test('residents cannot query the estate audit log', async () => {
  const { prisma } = reportsFake('RESIDENT');
  const service = new ReportsService(prisma);
  await assert.rejects(service.audit('resident-1', 'estate-1', {}), /management access/);
});

test('managers can query the audit log', async () => {
  const { prisma } = reportsFake('ESTATE_MANAGER');
  const service = new ReportsService(prisma);
  const result = await service.audit('manager-1', 'estate-1', {});
  assert.ok(Array.isArray(result.items));
});

function contextFor(ip) {
  return { switchToHttp: () => ({ getRequest: () => ({ method: 'POST', originalUrl: '/api/v1/estate/wallets/funding-intents', headers: { 'x-forwarded-for': ip } }) }) };
}

test('rate limit guard blocks requests over the configured threshold', () => {
  process.env.RATE_LIMIT_MAX = '2';
  process.env.RATE_LIMIT_WINDOW_MS = '60000';
  const guard = new RateLimitGuard();
  assert.equal(guard.canActivate(contextFor('1.2.3.4')), true);
  assert.equal(guard.canActivate(contextFor('1.2.3.4')), true);
  assert.throws(() => guard.canActivate(contextFor('1.2.3.4')), /Too many requests/);
  assert.equal(guard.canActivate(contextFor('5.6.7.8')), true);
});

test('rate limit guard skips health checks', () => {
  process.env.RATE_LIMIT_MAX = '1';
  const guard = new RateLimitGuard();
  const health = { switchToHttp: () => ({ getRequest: () => ({ method: 'GET', originalUrl: '/api/v1/health/ready', headers: {} }) }) };
  assert.equal(guard.canActivate(health), true);
  assert.equal(guard.canActivate(health), true);
});
