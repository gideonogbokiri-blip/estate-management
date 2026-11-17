import 'dotenv/config';
import { randomBytes, randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import { hashAccountPassword } from '../auth/password-hash.js';

const CONFIRMATION = '--confirm-local-demo';

async function main() {
  if (process.argv[2] !== CONFIRMATION) {
    throw new Error(`Usage: npm run seed:demo -- ${CONFIRMATION}`);
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('The local demo seed is disabled when NODE_ENV is production.');
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL must be configured.');
  const databaseHost = new URL(connectionString).hostname.toLowerCase();
  if (!['localhost', '127.0.0.1', '::1'].includes(databaseHost)
    && !process.argv.includes('--allow-remote-demo-seed')) {
    throw new Error('The local demo seed requires an empty users and estates database. Pass --allow-remote-demo-seed only for a fresh hosted demo database.');
  }

  const managerEmail = 'estate.manager.demo@example.test';
  const residentEmail = 'estate.resident.demo@example.test';
  const managerPassword = `Demo-${randomBytes(12).toString('base64url')}`;
  const residentPassword = `Demo-${randomBytes(12).toString('base64url')}`;
  const [managerPasswordHash, residentPasswordHash] = await Promise.all([
    hashAccountPassword(managerPassword),
    hashAccountPassword(residentPassword),
  ]);
  const now = new Date();
  const activeFrom = new Date(Date.UTC(now.getUTCFullYear() - 1, now.getUTCMonth(), 1));
  const currentYear = now.getUTCFullYear();

  const prisma = new PrismaService();
  try {
    if ((await prisma.user.count()) > 0 || (await prisma.estate.count()) > 0) {
      throw new Error('The local demo seed requires an empty users and estates database; no changes were made.');
    }

    const result = await prisma.$transaction(async (tx) => {
      const manager = await tx.user.create({ data: {
        emailNormalized: managerEmail,
        displayName: 'Estate Demo Manager',
        passwordHash: managerPasswordHash,
      } });
      const resident = await tx.user.create({ data: {
        emailNormalized: residentEmail,
        displayName: 'Estate Demo Resident',
        passwordHash: residentPasswordHash,
      } });
      const application = await tx.estateApplication.create({ data: {
        applicationCode: `DEMO-${randomUUID().slice(0, 8).toUpperCase()}`,
        applicantUserId: manager.id,
        proposedName: 'Palm Crest Residences (Demo)',
        estateType: 'Gated community',
        address: 'Lekki-Epe Expressway',
        state: 'Lagos',
        lga: 'Eti-Osa',
        applicantRelationship: 'Management company',
        applicantContactName: manager.displayName,
        applicantContactEmail: manager.emailNormalized,
        managementEntityName: 'Palm Crest Demo Management',
        homeCount: 186,
        phaseCount: 4,
        structureSummary: 'Four zones with streets and residential homes.',
        status: 'APPROVED',
        submittedAt: now,
        decidedByUserId: manager.id,
        decidedAt: now,
        initialAdministratorId: manager.id,
      } });
      const estate = await tx.estate.create({ data: {
        estateCode: 'LANCON-PALM-CREST-DEMO',
        approvedApplicationId: application.id,
        name: 'Palm Crest Residences (Demo)',
        estateType: 'Gated community',
        address: 'Lekki-Epe Expressway',
        state: 'Lagos',
        lga: 'Eti-Osa',
        status: 'ACTIVE',
        activatedAt: now,
      } });
      const properties = await Promise.all(Array.from({ length: 6 }, (_, index) =>
        tx.estateProperty.create({ data: {
          estateId: estate.id,
          code: `PC-${String(index + 1).padStart(3, '0')}`,
          propertyType: index === 5 ? 'Apartment' : 'Detached house',
          unitNumber: `Unit ${index + 1}`,
          address: `${index + 1} Palm Crest Way, Lekki`,
          description: 'Local presentation demo property.',
          createdByUserId: manager.id,
        } }),
      ));

      await tx.estateMembership.createMany({ data: [
        { estateId: estate.id, userId: manager.id, role: 'ESTATE_ADMINISTRATOR' },
        { estateId: estate.id, userId: resident.id, role: 'RESIDENT' },
      ] });
      await tx.propertyOccupancy.create({ data: {
        estateId: estate.id,
        propertyId: properties[0].id,
        residentId: resident.id,
        relationship: 'TENANT',
        status: 'ACTIVE',
        effectiveFrom: activeFrom,
        createdById: manager.id,
      } });

      const charge = await tx.estateChargeDefinition.create({ data: {
        estateId: estate.id,
        code: 'ANNUAL-SERVICE',
        createdById: manager.id,
      } });
      await tx.estateChargeVersion.create({ data: {
        chargeId: charge.id,
        versionNumber: 1,
        name: 'Annual estate service charge (demo)',
        description: 'Local demo data; no payment is due.',
        category: 'service_charge',
        amount: '50000.00',
        currency: 'NGN',
        recurrence: 'ANNUALLY',
        effectiveFrom: new Date(Date.UTC(currentYear, 0, 1)),
        dueDay: 15,
        graceDays: 7,
        appliesTo: 'ESTATE',
        status: 'ACTIVE',
        createdById: manager.id,
        activatedById: manager.id,
        activatedAt: now,
      } });
      await tx.estateAnnouncement.create({ data: {
        estateId: estate.id,
        title: 'Welcome to Palm Crest (Demo)',
        body: 'This local demonstration shows how estate updates appear for residents. No external message has been sent.',
        audience: 'ALL_RESIDENTS',
        status: 'PUBLISHED',
        createdById: manager.id,
        publishedAt: now,
      } });
      await tx.estateFacility.create({ data: {
        estateId: estate.id,
        code: 'CLUBHOUSE-DEMO',
        name: 'Community clubhouse',
        category: 'community',
        description: 'A shared space for estate residents.',
        location: 'Central park',
        capacity: 40,
        durationMinutes: 60,
        openingTime: '08:00',
        closingTime: '22:00',
        bookingLeadHours: 2,
        approvalMode: 'MANUAL',
        policyVersion: 1,
        active: true,
        createdById: manager.id,
      } });
      await tx.auditEvent.create({ data: {
        actorUserId: null,
        scope: 'platform',
        action: 'local_demo.seeded',
        targetType: 'estate',
        targetId: estate.id,
        outcome: 'success',
        occurredAt: now,
        metadata: { accountCount: 2, estateCode: estate.estateCode, source: 'operator_cli' },
      } });
      return { estate, propertyCount: properties.length };
    }, { isolationLevel: 'Serializable' });

    process.stdout.write([
      'Local presentation demo is ready.',
      `Estate: ${result.estate.name} (${result.propertyCount} properties)`,
      `Manager login: ${managerEmail}`,
      `Manager password: ${managerPassword}`,
      `Resident login: ${residentEmail}`,
      `Resident password: ${residentPassword}`,
      'Manager: http://localhost:8765/admin/',
      'Resident: http://localhost:8765/web/',
    ].join('\n') + '\n');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(() => {
  process.stderr.write('Local demo setup failed. Check the local database and retry; no environment secrets were printed.\n');
  process.exitCode = 1;
});
