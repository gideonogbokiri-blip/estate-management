const test = require('node:test');
const assert = require('node:assert/strict');
const { LedgerService } = require('../dist/src/properties/ledger.service.js');

function fakePrisma() {
  const journals = new Map();
  const entries = [];
  let counter = 0;
  const tx = {
    ledgerJournal: {
      create: async ({ data }) => {
        const id = `journal-${++counter}`;
        const record = { id, status: 'posted', ...data, entries: [] };
        journals.set(id, record);
        return { id };
      },
      findUnique: async ({ where }) => journals.get(where.id) ?? null,
      update: async ({ where, data }) => {
        const record = journals.get(where.id);
        Object.assign(record, data);
        return record;
      },
    },
    ledgerEntry: {
      createMany: async ({ data }) => {
        for (const row of data) {
          entries.push({ id: `entry-${entries.length + 1}`, ...row });
          journals.get(row.journalId).entries.push(entries[entries.length - 1]);
        }
      },
    },
  };
  return { tx, journals, entries };
}

function amount(value) {
  const text = String(value);
  return { lte: (other) => Number(text) <= Number(other), toString: () => text };
}

test('a posted journal has exactly two balanced entries', async () => {
  const { tx, entries, journals } = fakePrisma();
  const ledger = new LedgerService({});
  const journalId = await ledger.post(tx, {
    estateId: 'estate-1',
    reference: 'JRN-TEST-1',
    sourceType: 'test',
    description: 'Funding',
    currency: 'NGN',
    debitAccount: ledger.providerClearing('paystack', 'NGN'),
    creditAccount: ledger.walletAccount('wallet-1'),
    amount: amount('125000.00'),
  });
  assert.equal(entries.length, 2);
  assert.equal(journals.get(journalId).status, 'posted');
  const debit = entries.find((e) => e.direction === 'debit');
  const credit = entries.find((e) => e.direction === 'credit');
  assert.equal(debit.amount.toString(), credit.amount.toString());
  assert.equal(debit.accountCode, ledger.providerClearing('paystack', 'NGN'));
  assert.equal(credit.accountCode, ledger.walletAccount('wallet-1'));
});

test('posting rejects unbalanced or same-account instructions', async () => {
  const { tx } = fakePrisma();
  const ledger = new LedgerService({});
  await assert.rejects(
    ledger.post(tx, {
      reference: 'JRN-TEST-2', sourceType: 'test', description: 'bad', currency: 'NGN',
      debitAccount: 'A', creditAccount: 'A', amount: amount('10.00'),
    }),
    /Debit and credit accounts must differ/,
  );
  await assert.rejects(
    ledger.post(tx, {
      reference: 'JRN-TEST-3', sourceType: 'test', description: 'bad', currency: 'NGN',
      debitAccount: 'A', creditAccount: 'B', amount: amount('0'),
    }),
    /Ledger amount must be positive/,
  );
});

test('reversal posts compensating entries and preserves the original', async () => {
  const { tx, entries, journals } = fakePrisma();
  const ledger = new LedgerService({});
  const originalId = await ledger.post(tx, {
    reference: 'JRN-TEST-4', sourceType: 'test', description: 'Rent', currency: 'NGN',
    debitAccount: ledger.walletAccount('wallet-1'),
    creditAccount: ledger.estateCollection('estate-1', 'NGN'),
    amount: amount('5000.00'),
  });
  const reversalId = await ledger.reverse(tx, originalId, 'Provider reversal');
  assert.notEqual(reversalId, originalId);
  assert.equal(journals.get(originalId).status, 'reversed');
  assert.equal(entries.length, 4);
  const reversalEntries = entries.filter((e) => e.journalId === reversalId);
  const reversalDebit = reversalEntries.find((e) => e.direction === 'debit');
  assert.equal(reversalDebit.accountCode, ledger.estateCollection('estate-1', 'NGN'));
  assert.equal(reversalDebit.amount.toString(), '5000.00');
});
