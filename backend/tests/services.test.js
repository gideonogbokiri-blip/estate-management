const test = require('node:test');
const assert = require('node:assert/strict');
const { EstateServicesService } = require('../dist/src/properties/services.service.js');
const { Prisma } = require('../dist/src/generated/prisma/client.js');

const dec = (value) => new Prisma.Decimal(value);

function fake({ balance = '100000.00' } = {}) {
  let role = 'RESIDENT';
  const definitions = [];
  const orders = new Map();
  const definitionsById = new Map();
  const audit = [];
  const walletId = 'wallet-1';
  const prisma = {
    estateMembership: { findFirst: async ({ where }) => {
      if (where.role?.in && !where.role.in.includes(role)) return null;
      return { role };
    } },
    estateServiceDefinition: {
      findMany: async () => definitions,
      findFirst: async ({ where }) => definitions.find((row) => Object.entries(where).every(([k, v]) => row[k] === v)) ?? null,
      create: async ({ data }) => {
        const row = { ...data, id: `service-${definitions.length + 1}`, createdAt: new Date(), amount: dec(data.amount) };
        definitions.push(row);
        definitionsById.set(row.id, row);
        return row;
      },
      update: async ({ where, data }) => {
        const row = definitionsById.get(where.id);
        Object.assign(row, data);
        return row;
      },
    },
    estateWallet: { findUnique: async () => ({ id: walletId, status: 'active' }) },
    estateWalletTransaction: { groupBy: async () => [
      { type: 'credit', _sum: { amount: dec(balance) } },
      { type: 'debit', _sum: { amount: dec('0.00') } },
    ], create: async () => ({}) },
    estateServiceOrder: {
      findUnique: async ({ where }) => {
        const { idempotencyKeyHash } = where.estateId_orderedBy_idempotencyKeyHash;
        return [...orders.values()].find((row) => row.idempotencyKeyHash === idempotencyKeyHash) ?? null;
      },
      create: async ({ data }) => {
        const row = { ...data, id: `order-${orders.size + 1}`, amount: dec(data.amount), createdAt: new Date() };
        orders.set(row.id, row);
        return row;
      },
    },
    auditEvent: { create: async ({ data }) => { audit.push(data); return {}; } },
    $queryRaw: async () => [],
    $transaction: async (callback) => callback(prisma),
  };
  const ledger = {
    post: async (_tx, input) => { ledger.lastPosting = input; return 'journal-1'; },
    walletAccount: (id) => `WALLET:${id}`,
    providerClearing: (provider, currency) => `PROVIDER_CLEARING:${provider.toUpperCase()}:${currency}`,
  };
  return {
    prisma, ledger,
    setRole: (value) => { role = value; },
    getDefinitions: () => definitions,
    getOrders: () => [...orders.values()],
    getAudit: () => audit,
  };
}

const serviceInput = {
  code: 'AIRTIME', name: 'Airtime top-up', category: 'utilities',
  provider: 'demo', amount: '1000.00', currency: 'NGN',
};
const key = 'order-idempotency-key-0000000000000001';

test('manager creates a clearly labelled demo service', async () => {
  const { prisma, ledger, setRole, getDefinitions } = fake();
  setRole('ESTATE_MANAGER');
  const service = new EstateServicesService(prisma, ledger);
  const created = await service.createDefinition('manager-1', 'estate-1', serviceInput);
  assert.equal(created.demo, true);
  assert.equal(created.code, 'AIRTIME');
  assert.equal(getDefinitions()[0].status, 'ACTIVE');
});

test('residents cannot create service definitions', async () => {
  const { prisma, ledger } = fake();
  const service = new EstateServicesService(prisma, ledger);
  await assert.rejects(
    service.createDefinition('resident-1', 'estate-1', serviceInput),
    /management access/,
  );
});

test('wallet-funded service order is fulfilled with a voucher', async () => {
  const { prisma, ledger, setRole, getAudit, getOrders } = fake();
  setRole('ESTATE_MANAGER');
  const service = new EstateServicesService(prisma, ledger);
  const definition = await service.createDefinition('manager-1', 'estate-1', serviceInput);
  setRole('RESIDENT');
  const order = await service.order('resident-1', 'estate-1', definition.id, key);
  assert.equal(order.status, 'fulfilled');
  assert.equal(order.provider, 'LANCON Services');
  assert.equal(order.fulfilmentCode.startsWith('LAN-'), true);
  assert.equal(ledger.lastPosting.debitAccount, 'WALLET:wallet-1');
  assert.equal(ledger.lastPosting.creditAccount, 'PROVIDER_CLEARING:LANCON:NGN');
  assert.equal(getOrders().length, 1);
  assert.equal(getAudit().at(-1).action, 'estate_service.ordered_demo');
});

test('service order is idempotent by key', async () => {
  const { prisma, ledger, setRole, getOrders } = fake();
  setRole('ESTATE_MANAGER');
  const service = new EstateServicesService(prisma, ledger);
  const definition = await service.createDefinition('manager-1', 'estate-1', serviceInput);
  setRole('RESIDENT');
  const first = await service.order('resident-1', 'estate-1', definition.id, key);
  const second = await service.order('resident-1', 'estate-1', definition.id, key);
  assert.equal(first.replayed, false);
  assert.equal(second.replayed, true);
  assert.equal(getOrders().length, 1);
});

test('service order requires sufficient wallet balance', async () => {
  const { prisma, ledger, setRole } = fake({ balance: '100.00' });
  setRole('ESTATE_MANAGER');
  const service = new EstateServicesService(prisma, ledger);
  const definition = await service.createDefinition('manager-1', 'estate-1', serviceInput);
  setRole('RESIDENT');
  await assert.rejects(
    service.order('resident-1', 'estate-1', definition.id, key),
    /Insufficient fund account balance/,
  );
});
