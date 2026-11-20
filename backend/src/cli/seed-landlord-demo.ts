import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { hashAccountPassword } from '../auth/password-hash.js';
import { DEMO_ESTATE_PREFIX, DEMO_PASSWORD, demoEmails } from './demo-credentials.js';

const CONFIRMATION = '--confirm-landlord-demo';

const EMAIL = demoEmails(DEMO_ESTATE_PREFIX).landlord;
const PASSWORD = DEMO_PASSWORD;
const DISPLAY_NAME = 'Estate Demo Landlord';
const ESTATE_NAME = 'Palm Crest Residences (Demo)';
const PROPERTY_CODE = 'PC-002';

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(`Usage: npm run seed:landlord-demo -- ${CONFIRMATION}`);
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Demo account seeding is disabled when NODE_ENV is production.');
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL must be configured.');
  const host = new URL(connectionString).hostname.toLowerCase();
  if (!['localhost', '127.0.0.1', '::1'].includes(host)
    && !process.argv.includes('--allow-remote-demo-seed')) {
    throw new Error('Pass --allow-remote-demo-seed to seed a hosted demo database.');
  }

  const prisma = new PrismaService();
  try {
    const estate = await prisma.estate.findFirst({
      where: { name: ESTATE_NAME, status: 'ACTIVE' },
      select: { id: true },
    });
    if (!estate) throw new Error(`Active ${ESTATE_NAME} estate not found.`);
    const property = await prisma.estateProperty.findFirst({
      where: { estateId: estate.id, code: PROPERTY_CODE },
      select: { id: true },
    });
    if (!property) throw new Error(`${PROPERTY_CODE} was not found in the demo estate.`);
    const manager = await prisma.estateMembership.findFirst({
      where: { estateId: estate.id, role: 'ESTATE_ADMINISTRATOR', status: 'ACTIVE' },
      select: { userId: true },
      orderBy: { createdAt: 'asc' },
    });
    if (!manager) throw new Error('An active estate administrator is required to verify ownership.');

    const passwordHash = await hashAccountPassword(PASSWORD);
    const landlord = await prisma.user.upsert({
      where: { emailNormalized: EMAIL },
      update: { status: 'ACTIVE', displayName: DISPLAY_NAME, passwordHash },
      create: { emailNormalized: EMAIL, displayName: DISPLAY_NAME, passwordHash },
      select: { id: true },
    });

    const existing = await prisma.estateOwnershipInterest.findFirst({
      where: { estateId: estate.id, propertyId: property.id, ownerUserId: landlord.id },
      select: { id: true },
    });
    if (!existing) {
      const effectiveFrom = new Date();
      effectiveFrom.setUTCFullYear(effectiveFrom.getUTCFullYear() - 1);
      const interest = await prisma.estateOwnershipInterest.create({ data: {
        estateId: estate.id,
        propertyId: property.id,
        ownerUserId: landlord.id,
        ownershipShare: '100.00',
        effectiveFrom,
        status: 'ACTIVE',
        verificationStatus: 'VERIFIED',
        evidenceNote: 'Local presentation demo: verified ownership evidence recorded by the estate administrator.',
        reviewedById: manager.userId,
        reviewedAt: new Date(),
        createdById: manager.userId,
      }, select: { id: true } });
      await prisma.auditEvent.create({ data: {
        actorUserId: manager.userId,
        scope: 'estate',
        estateId: estate.id,
        action: 'ownership.verify',
        targetType: 'ownership_interest',
        targetId: interest.id,
        outcome: 'success',
        occurredAt: new Date(),
        metadata: { source: 'local_landlord_demo_seed' },
      } });
    }

    await prisma.estateMembership.upsert({
      where: {
        estateId_userId_role: { estateId: estate.id, userId: landlord.id, role: 'LANDLORD' },
      },
      update: { status: 'ACTIVE' },
      create: { estateId: estate.id, userId: landlord.id, role: 'LANDLORD' },
    });

    process.stdout.write(`\nLandlord demo ready\n  ${EMAIL}\n  ${PASSWORD}\n  Verified ownership: ${PROPERTY_CODE}\n\n`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Landlord demo seed failed.'}\n`);
  process.exitCode = 1;
});
