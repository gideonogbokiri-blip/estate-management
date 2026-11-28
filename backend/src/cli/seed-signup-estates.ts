import 'dotenv/config';
import { createHash } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';

const CONFIRMATION = '--confirm-signup-estates';
const hash = (value: string) => createHash('sha256').update(value, 'utf8').digest('hex');

const ESTATES = [
  {
    name: 'Terra Crest Estate',
    code: 'TERRA-CREST',
    state: 'Lagos',
    lga: 'Eti-Osa',
    address: 'Emerald Living Sanctuary, Cluster Alpha-A',
    properties: ['A-101', 'A-102', 'A-103', 'A-104', 'B-201', 'B-202'],
  },
  {
    name: 'Greenfield Residence',
    code: 'GREENFIELD',
    state: 'Lagos',
    lga: 'Ikeja',
    address: 'Greenfield Close, Omole Phase 2',
    properties: ['G-001', 'G-002', 'G-003', 'G-004'],
  },
  {
    name: 'Harbour View Estate',
    code: 'HARBOUR-VIEW',
    state: 'Lagos',
    lga: 'Lekki',
    address: 'Harbour View Drive, Lekki Phase 1',
    properties: ['H-001', 'H-002', 'H-003', 'H-004', 'H-005'],
  },
];

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(`Usage: npm run seed:signup-estates -- ${CONFIRMATION} [--allow-remote-demo-seed]`);
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
    const creator = await prisma.user.findFirst({
      where: { emailNormalized: 'pc@testlancon.com' }, select: { id: true },
    });
    if (!creator) throw new Error('Seed administrator not found.');

    for (const plan of ESTATES) {
      const existing = await prisma.estate.findFirst({ where: { name: plan.name }, select: { id: true } });
      const estateId = existing?.id ?? await (async () => {
        const application = await prisma.estateApplication.create({
          data: {
            applicationCode: `APP-${plan.code}-${hash(plan.code).slice(0, 6).toUpperCase()}`,
            applicantUserId: creator.id, proposedName: plan.name,
            estateType: 'Gated community', address: plan.address,
            state: plan.state, lga: plan.lga, applicantRelationship: 'Management company',
            applicantContactName: 'LANCON Demo', applicantContactEmail: 'pc@testlancon.com',
            managementEntityName: `${plan.name} Management`,
            homeCount: plan.properties.length, phaseCount: 1,
            structureSummary: `${plan.properties.length} residential homes.`,
            status: 'APPROVED', submittedAt: new Date(),
            decidedByUserId: creator.id, decidedAt: new Date(),
            initialAdministratorId: creator.id,
          },
          select: { id: true },
        });
        return prisma.estate.create({
          data: {
            estateCode: plan.code, name: plan.name, estateType: 'Gated community',
            address: plan.address, state: plan.state, lga: plan.lga,
            status: 'ACTIVE', activatedAt: new Date(),
            approvedApplicationId: application.id,
          },
          select: { id: true },
        });
      })().then((estate) => estate.id);
      let createdProperties = 0;
      for (const code of plan.properties) {
        const property = await prisma.estateProperty.findFirst({
          where: { estateId, code }, select: { id: true },
        });
        if (property) continue;
        await prisma.estateProperty.create({
          data: {
            estateId, code, propertyType: 'Apartment', status: 'ACTIVE',
            unitNumber: code, description: `${plan.name} residential unit`,
            createdByUserId: creator.id,
          },
        });
        createdProperties += 1;
      }
      const count = await prisma.estateChargeDefinition.count({ where: { estateId } });
      if (count === 0) {
        const definition = await prisma.estateChargeDefinition.create({
          data: { estateId, code: 'SERVICE', createdById: creator.id },
        });
        await prisma.estateChargeVersion.create({
          data: {
            chargeId: definition.id, versionNumber: 1,
            name: 'Annual estate service charge', category: 'service_charge',
            amount: 24000, currency: 'NGN', recurrence: 'ANNUALLY',
            effectiveFrom: new Date('2026-01-01T00:00:00.000Z'),
            dueDay: 15, graceDays: 7, appliesTo: 'ESTATE',
            status: 'ACTIVE', createdById: creator.id,
            activatedById: creator.id, activatedAt: new Date(),
          },
        });
        const invoiceId = crypto.randomUUID();
        await prisma.estateInvoiceDraft.create({
          data: {
            id: invoiceId, estateId,
            invoiceNumber: `INV-${hash(plan.code).slice(0, 16).toUpperCase()}`,
            chargeVersionId: (await prisma.estateChargeVersion.findFirst({
              where: { chargeId: definition.id }, select: { id: true },
            }))!.id,
            propertyId: (await prisma.estateProperty.findFirst({
              where: { estateId }, select: { id: true },
            }))!.id,
            payerUserId: creator.id, createdById: creator.id,
            periodStart: new Date('2026-01-01T00:00:00.000Z'),
            periodEnd: new Date('2026-12-31T00:00:00.000Z'),
            dueDate: new Date('2026-03-15T00:00:00.000Z'),
            currency: 'NGN', subtotal: 24000, total: 24000,
            lineSnapshot: [{
              chargeCode: 'SERVICE', chargeVersion: 1,
              description: 'Annual estate service charge', category: 'service_charge',
              amount: '24000', currency: 'NGN', quantity: '1',
              periodStart: '2026-01-01', periodEnd: '2026-12-31', periodDays: 365,
            }],
            status: 'ISSUED',
            idempotencyKeyHash: hash(`signup-estate-invoice:${plan.code}`),
            payloadHash: hash(`signup-estate:${plan.code}`),
            issuedAt: new Date(),
          },
        }).catch(() => undefined);
      }
      process.stdout.write(`${plan.name}: ${createdProperties} new properties\n`);
    }
    const total = await prisma.estate.count({ where: { status: 'ACTIVE' } });
    process.stdout.write(`Active estates available for signup: ${total}\n`);
  } finally {
    await prisma.$disconnect();
  }
}

import { randomUUID as cryptoRandomUUID } from 'node:crypto';
const crypto = { randomUUID: cryptoRandomUUID };

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Seed failed.'}\n`);
  process.exitCode = 1;
});
