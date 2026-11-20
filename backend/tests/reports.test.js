const test = require('node:test');
const assert = require('node:assert/strict');
const { Prisma } = require('../dist/src/generated/prisma/client.js');
const { ReportsService } = require('../dist/src/properties/reports.service.js');

test('manager report summary aggregates invoices, rent, expenses and payouts', async () => {
  const dec = (value) => new Prisma.Decimal(value);
  const prisma = {
    estateMembership: { findFirst: async () => ({ role: 'ESTATE_ADMINISTRATOR' }) },
    estateInvoiceDraft: { findMany: async () => [
      { status: 'ISSUED', total: dec('100.00'), currency: 'NGN' },
      { status: 'PAID', total: dec('50.00'), currency: 'NGN' },
    ] },
    rentSchedule: { findMany: async () => [{
      amount: dec('200.00'), currency: 'NGN',
      payments: [{ amount: dec('80.00') }],
    }] },
    estateExpenseRequest: { findMany: async () => [
      { status: 'PENDING', amount: dec('30.00'), currency: 'NGN' },
    ] },
    estatePayoutRequest: { findMany: async () => [
      { status: 'PENDING_APPROVAL', amount: dec('20.00'), currency: 'NGN' },
    ] },
    auditEvent: { count: async () => 7 },
  };
  const service = new ReportsService(prisma);
  const summary = await service.managerSummary('manager-1', 'estate-1');
  assert.equal(summary.currency, 'NGN');
  assert.equal(summary.invoices.total, 2);
  assert.equal(summary.invoices.issued, 1);
  assert.equal(summary.rent.entitlement, '200');
  assert.equal(summary.rent.collected, '80');
  assert.equal(summary.rent.outstanding, '120');
  assert.equal(summary.expenses.pending, 1);
  assert.equal(summary.payouts.pending, 1);
  assert.equal(summary.auditEvents, 7);
});

test('non-managers cannot read the report summary', async () => {
  const prisma = {
    estateMembership: { findFirst: async () => null },
  };
  const service = new ReportsService(prisma);
  await assert.rejects(
    service.managerSummary('resident-1', 'estate-1'),
    /management access/,
  );
});
