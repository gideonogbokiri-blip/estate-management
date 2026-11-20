import 'dotenv/config';
import { createHash } from 'node:crypto';
import { hashAccountPassword } from '../auth/password-hash.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { DEMO_ESTATE_PREFIX, DEMO_PASSWORD, demoEmails } from './demo-credentials.js';

const CONFIRMATION = '--confirm-local-gate-demo';
const RESET_FLAG = '--reset';

const DEMO_ESTATE_NAME = 'Palm Crest Residences (Demo)';
const OFFICER_EMAIL = demoEmails(DEMO_ESTATE_PREFIX).security;
const OFFICER_NAME = 'Estate Demo Security Officer';
const OFFICER_PASSWORD = DEMO_PASSWORD;
const RESIDENT_EMAIL = demoEmails(DEMO_ESTATE_PREFIX).resident;
const GATE_CODE = 'MAIN';
const GATE_NAME = 'Main Gate';

interface SeedPass {
  key: string;
  visitorName: string;
  validHours: number;
  vehicleSummary?: string;
  checkedInMinutesAgo?: number;
}

const SEED_PASSES: readonly SeedPass[] = [
  { key: 'adaeze', visitorName: 'Adaeze Nnadi', validHours: 6, vehicleSummary: 'Blue sedan - LND 219 GK' },
  { key: 'chinwe', visitorName: 'Chinwe Okoro', validHours: 8 },
  { key: 'northstar', visitorName: 'Northstar Plumbing', validHours: 5, vehicleSummary: 'White van - PLM 480 XA' },
  { key: 'samuel', visitorName: 'Samuel Eze', validHours: 12, checkedInMinutesAgo: 35 },
];

function visitorCredential(key: string): string {
  return createHash('sha256')
    .update(`lancon-gate-demo:v1:${key}`, 'utf8')
    .digest('base64url');
}

function credentialHash(credential: string): string {
  return createHash('sha256').update(credential, 'utf8').digest('hex');
}

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(
      `Usage: npm run seed:gate-demo -- ${CONFIRMATION} [${RESET_FLAG}]`,
    );
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('The local gate demo seed is disabled when NODE_ENV is production.');
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL must be configured.');
  const databaseHost = new URL(connectionString).hostname.toLowerCase();
  if (!['localhost', '127.0.0.1', '::1'].includes(databaseHost)
    && !process.argv.includes('--allow-remote-demo-seed')) {
    throw new Error('The gate demo seed only runs against a local database unless --allow-remote-demo-seed is passed for a hosted demo.');
  }

  const prisma = new PrismaService();
  try {
    const estate = await prisma.estate.findFirst({
      where: { name: DEMO_ESTATE_NAME, status: 'ACTIVE' },
      select: { id: true, name: true },
    });
    if (!estate) {
      throw new Error(
        `The active ${DEMO_ESTATE_NAME} estate was not found. Seed the local demo estate first.`,
      );
    }
    const resident = await prisma.user.findUnique({
      where: { emailNormalized: RESIDENT_EMAIL },
      select: { id: true },
    });
    if (!resident) {
      throw new Error(`The resident demo account ${RESIDENT_EMAIL} was not found.`);
    }
    const occupancy = await prisma.propertyOccupancy.findFirst({
      where: { estateId: estate.id, residentId: resident.id, status: 'ACTIVE' },
      select: { propertyId: true, property: { select: { code: true } } },
      orderBy: { createdAt: 'asc' },
    });
    if (!occupancy) {
      throw new Error('The resident demo account has no active occupancy in the demo estate.');
    }

    const passwordHash = await hashAccountPassword(OFFICER_PASSWORD);
    const officer = await prisma.user.upsert({
      where: { emailNormalized: OFFICER_EMAIL },
      update: { status: 'ACTIVE', passwordHash },
      create: {
        emailNormalized: OFFICER_EMAIL,
        displayName: OFFICER_NAME,
        passwordHash,
      },
      select: { id: true },
    });
    await prisma.estateMembership.upsert({
      where: {
        estateId_userId_role: {
          estateId: estate.id,
          userId: officer.id,
          role: 'SECURITY_OFFICER',
        },
      },
      update: { status: 'ACTIVE' },
      create: { estateId: estate.id, userId: officer.id, role: 'SECURITY_OFFICER' },
    });
    const administrator = await prisma.estateMembership.findFirst({
      where: {
        estateId: estate.id,
        role: { in: ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER'] },
        status: 'ACTIVE',
      },
      select: { userId: true },
      orderBy: { createdAt: 'asc' },
    });
    if (!administrator) {
      throw new Error('The demo estate has no active administrator to assign gate staff.');
    }

    const gate = await prisma.estateGate.upsert({
      where: { estateId_code: { estateId: estate.id, code: GATE_CODE } },
      update: { name: GATE_NAME, active: true },
      create: { estateId: estate.id, code: GATE_CODE, name: GATE_NAME },
      select: { id: true, name: true },
    });
    const now = new Date();
    const assignment = await prisma.estateGateAssignment.findFirst({
      where: {
        estateId: estate.id,
        gateId: gate.id,
        userId: officer.id,
        activeTo: null,
        activeFrom: { lte: now },
      },
      select: { id: true },
    });
    if (!assignment) {
      const created = await prisma.estateGateAssignment.create({
        data: {
          estateId: estate.id,
          gateId: gate.id,
          userId: officer.id,
          assignedById: administrator.userId,
          activeFrom: now,
        },
        select: { id: true },
      });
      await prisma.auditEvent.create({
        data: {
          actorUserId: administrator.userId,
          scope: 'estate',
          estateId: estate.id,
          action: 'security.gate.assign',
          targetType: 'gate_assignment',
          targetId: created.id,
          outcome: 'success',
          occurredAt: now,
          metadata: { gateId: gate.id, assignedUserId: officer.id, source: 'local_gate_demo_seed' },
        },
      });
    }

    const contactSeeds = [
      { label: 'Estate control room', displayName: 'Estate Control Room (demo)', phoneDisplay: '+234 800 000 0142' },
      { label: 'On-call manager', displayName: 'On-call Estate Manager (demo)', phoneDisplay: '+234 800 000 0124' },
    ];
    for (const contact of contactSeeds) {
      await prisma.estateSecurityContact.upsert({
        where: { estateId_label: { estateId: estate.id, label: contact.label } },
        update: { ...contact, active: true },
        create: { estateId: estate.id, ...contact },
      });
    }

    const seededHashes = SEED_PASSES.map((pass) => credentialHash(visitorCredential(pass.key)));
    if (process.argv.includes(RESET_FLAG)) {
      await prisma.$transaction(async (tx) => {
        const seededPasses = await tx.estateVisitorPass.findMany({
          where: { estateId: estate.id, credentialHash: { in: seededHashes } },
          select: { id: true },
        });
        const passIds = seededPasses.map((pass) => pass.id);
        const seededVisits = await tx.estateVisitorVisit.findMany({
          where: { passId: { in: passIds } },
          select: { id: true },
        });
        const manualVisits = await tx.estateVisitorVisit.findMany({
          where: { estateId: estate.id, gateId: gate.id, passId: null, admissionType: 'manual' },
          select: { id: true },
        });
        const visitIds = [...seededVisits, ...manualVisits].map((visit) => visit.id);
        await tx.estateAccessEvent.deleteMany({
          where: {
            estateId: estate.id,
            OR: [
              { passId: { in: passIds } },
              { visitId: { in: visitIds } },
            ],
          },
        });
        await tx.estateVisitorVisit.deleteMany({ where: { id: { in: visitIds } } });
        await tx.estateVisitorPass.deleteMany({ where: { id: { in: passIds } } });
        await tx.estateGateVerificationAttempt.deleteMany({
          where: { estateId: estate.id, gateId: gate.id },
        });
        await tx.estateGateCheckInIdempotency.deleteMany({
          where: { estateId: estate.id, gateId: gate.id },
        });
        await tx.estateGateManualAdmissionIdempotency.deleteMany({
          where: { estateId: estate.id, gateId: gate.id },
        });
      });
    }

    const createdPasses: Array<{ pass: SeedPass; credential: string }> = [];
    for (const pass of SEED_PASSES) {
      const credential = visitorCredential(pass.key);
      const existing = await prisma.estateVisitorPass.findUnique({
        where: { credentialHash: credentialHash(credential) },
        select: { id: true },
      });
      if (existing) continue;
      const checkedIn = pass.checkedInMinutesAgo !== undefined;
      const createdAt = new Date(now.getTime() - 60 * 60 * 1000);
      const record = await prisma.estateVisitorPass.create({
        data: {
          estateId: estate.id,
          propertyId: occupancy.propertyId,
          hostUserId: resident.id,
          visitorDisplayName: pass.visitorName,
          credentialHash: credentialHash(credential),
          validFrom: new Date(now.getTime() - 5 * 60 * 1000),
          validUntil: new Date(now.getTime() + pass.validHours * 60 * 60 * 1000),
          allowedUses: 1,
          useCount: checkedIn ? 1 : 0,
          vehicleSummary: pass.vehicleSummary ?? null,
          createdAt,
        },
        select: { id: true },
      });
      if (checkedIn) {
        const checkedInAt = new Date(now.getTime() - (pass.checkedInMinutesAgo ?? 0) * 60 * 1000);
        const visit = await prisma.estateVisitorVisit.create({
          data: {
            estateId: estate.id,
            passId: record.id,
            propertyId: occupancy.propertyId,
            gateId: gate.id,
            admissionType: 'pass',
            visitorDisplayName: pass.visitorName,
            status: 'checked_in',
            checkedInByUserId: officer.id,
            checkedInAt,
          },
          select: { id: true },
        });
        await prisma.estateAccessEvent.create({
          data: {
            estateId: estate.id,
            passId: record.id,
            visitId: visit.id,
            propertyId: occupancy.propertyId,
            gateId: gate.id,
            staffUserId: officer.id,
            eventKind: 'entry',
            occurredAt: checkedInAt,
          },
        });
        await prisma.auditEvent.create({
          data: {
            actorUserId: officer.id,
            scope: 'gate',
            estateId: estate.id,
            action: 'visitor_pass.check_in',
            targetType: 'visitor_pass',
            targetId: record.id,
            outcome: 'success',
            occurredAt: checkedInAt,
            metadata: { gateId: gate.id, source: 'local_gate_demo_seed' },
          },
        });
      }
      createdPasses.push({ pass, credential });
    }

    const inside = SEED_PASSES.filter((pass) => pass.checkedInMinutesAgo !== undefined);
    const expected = SEED_PASSES.filter((pass) => pass.checkedInMinutesAgo === undefined);
    const lines = [
      '',
      `Gate demo estate: ${estate.name}`,
      `Security officer: ${OFFICER_EMAIL}`,
      `Password:        ${OFFICER_PASSWORD}`,
      `Assigned gate:   ${gate.name} (${GATE_CODE})`,
      `Property:        ${occupancy.property.code}`,
      '',
      'Expected visitor pass codes (shown once here; paste them into the gate app):',
      ...expected.map((pass) => `  ${pass.visitorName}: ${visitorCredential(pass.key)}`),
      '',
      `Already inside: ${inside.map((pass) => pass.visitorName).join(', ') || 'none'}`,
      `${createdPasses.length} new pass record(s) created; existing walkthrough passes were left unchanged.`,
      `Re-run with ${RESET_FLAG} to restore a pristine gate demo.`,
      '',
    ];
    process.stdout.write(`${lines.join('\n')}\n`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Gate demo seed failed.'}\n`);
  process.exitCode = 1;
});
