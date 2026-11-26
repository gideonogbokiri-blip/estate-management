import 'dotenv/config';
import { createHash } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';

const CONFIRMATION = '--confirm-terra-levies';

const hash = (value: string) => createHash('sha256').update(value, 'utf8').digest('hex');

const LEVIES = [
  {
    code: 'Q1-SECURITY',
    name: 'Q1 Security, Biometrics & Landscaping Levy',
    amount: 45000,
    category: 'security',
    dueDate: new Date('2025-03-31T00:00:00.000Z'),
    periodStart: new Date('2025-01-01T00:00:00.000Z'),
    periodEnd: new Date('2025-03-31T00:00:00.000Z'),
    note: 'Auto-debit available from Escrow',
  },
  {
    code: 'SOLAR-RESERVE',
    name: 'Solar Microgrid Reserve & Battery Replacement Fund',
    amount: 18500,
    category: 'utilities',
    dueDate: new Date('2026-10-31T00:00:00.000Z'),
    periodStart: new Date('2026-10-01T00:00:00.000Z'),
    periodEnd: new Date('2026-10-31T00:00:00.000Z'),
    note: 'Sinking Fund Contribution · Villa Lotus 12 allocation',
  },
];

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(`Usage: npm run terra:levies -- ${CONFIRMATION} [--allow-remote-demo-seed]`);
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL must be configured.');
  const host = new URL(connectionString).hostname.toLowerCase();
  if (!['localhost', '127.0.0.1', '::1'].includes(host)
    && !process.argv.includes('--allow-remote-demo-seed')) {
    throw new Error('Pass --allow-remote-demo-seed for the hosted database.');
  }

  const prisma = new PrismaService();
  try {
    const estate = await prisma.estate.findFirst({
      where: { status: 'ACTIVE' }, orderBy: { createdAt: 'asc' },
    });
    if (!estate) throw new Error('No active estate found.');
    const user = await prisma.user.findUnique({
      where: { emailNormalized: 'pcr@testlancon.com' }, select: { id: true },
    });
    const property = await prisma.estateProperty.findFirst({
      where: { estateId: estate.id, code: 'A-104' }, select: { id: true },
    });
    const manager = await prisma.user.findUnique({
      where: { emailNormalized: 'pc@testlancon.com' }, select: { id: true },
    });
    if (!user || !property || !manager) throw new Error('Terra Crest resident, property or manager not found.');

    for (const levy of LEVIES) {
      const definition = await prisma.estateChargeDefinition.upsert({
        where: { estateId_code: { estateId: estate.id, code: levy.code } },
        update: {},
        create: { estateId: estate.id, code: levy.code, createdById: manager.id },
      });
      const version = await prisma.estateChargeVersion.findFirst({
        where: { chargeId: definition.id }, orderBy: { versionNumber: 'desc' },
      });
      const versionId = version?.id ?? (
        await prisma.estateChargeVersion.create({
          data: {
            chargeId: definition.id, versionNumber: 1, name: levy.name,
            description: levy.note, category: levy.category, amount: levy.amount,
            currency: 'NGN', recurrence: 'ONE_TIME',
            effectiveFrom: levy.periodStart, effectiveTo: levy.periodEnd,
            dueDay: levy.dueDate.getUTCDate(), graceDays: 0, appliesTo: 'ESTATE',
            status: 'ACTIVE', createdById: manager.id, activatedById: manager.id,
            activatedAt: new Date(),
          },
          select: { id: true },
        })
      ).id;

      const keyHash = hash(`terra-levy:v1:${levy.code}`);
      const invoiceNumber = `INV-${hash(levy.code).slice(0, 16).toUpperCase()}`;
      const existing = await prisma.estateInvoiceDraft.findUnique({
        where: {
          createdById_estateId_idempotencyKeyHash: {
            createdById: manager.id, estateId: estate.id, idempotencyKeyHash: keyHash,
          },
        },
        select: { id: true },
      });
      if (existing) {
        process.stdout.write(`Already present: ${levy.code}\n`);
        continue;
      }
      await prisma.estateInvoiceDraft.create({
        data: {
          estateId: estate.id, invoiceNumber, chargeVersionId: versionId,
          propertyId: property.id, payerUserId: user.id, createdById: manager.id,
          periodStart: levy.periodStart, periodEnd: levy.periodEnd, dueDate: levy.dueDate,
          currency: 'NGN', subtotal: levy.amount, total: levy.amount,
          lineSnapshot: [{
            chargeCode: levy.code, chargeVersion: 1, description: levy.name,
            category: levy.category, amount: levy.amount.toString(), currency: 'NGN',
            quantity: '1', periodStart: levy.periodStart.toISOString().slice(0, 10),
            periodEnd: levy.periodEnd.toISOString().slice(0, 10), periodDays: 90,
          }],
          status: 'ISSUED', idempotencyKeyHash: keyHash,
          payloadHash: hash(`${levy.code}|${user.id}|${property.id}`),
          issuedAt: new Date(),
        },
      });
      process.stdout.write(`Created: ${levy.name}\n`);
    }
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Levy seed failed.'}\n`);
  process.exitCode = 1;
});
