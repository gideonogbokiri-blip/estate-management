import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { hashAccountPassword } from '../auth/password-hash.js';
import { DEMO_PASSWORD } from './demo-credentials.js';

const CONFIRMATION = '--confirm-chairman-demo';
const CHAIRMAN_EMAIL = 'chairman@testlancon.com';

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(`Usage: npm run seed:chairman-demo -- ${CONFIRMATION} [--allow-remote-demo-seed]`);
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
    const estate = await prisma.estate.findFirst({ where: { status: 'ACTIVE' }, orderBy: { createdAt: 'asc' } });
    if (!estate) throw new Error('No active estate found.');
    const passwordHash = await hashAccountPassword(DEMO_PASSWORD);
    const chairman = await prisma.user.upsert({
      where: { emailNormalized: CHAIRMAN_EMAIL },
      update: { displayName: 'Estate Chairman', status: 'ACTIVE', passwordHash },
      create: { emailNormalized: CHAIRMAN_EMAIL, displayName: 'Estate Chairman', passwordHash },
      select: { id: true },
    });
    await prisma.estateMembership.upsert({
      where: {
        estateId_userId_role: {
          estateId: estate.id, userId: chairman.id, role: 'ESTATE_CHAIRMAN',
        },
      },
      update: { status: 'ACTIVE' },
      create: {
        estateId: estate.id, userId: chairman.id,
        role: 'ESTATE_CHAIRMAN', status: 'ACTIVE',
      },
    });

    // The existing demo approver account becomes the estate administrator,
    // so initiation and approval are held by different people.
    const oldApprover = await prisma.user.findUnique({
      where: { emailNormalized: 'pca@testlancon.com' }, select: { id: true },
    });
    if (oldApprover) {
      await prisma.estateMembership.updateMany({
        where: {
          estateId: estate.id, userId: oldApprover.id,
          role: { in: ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN'] },
        },
        data: { role: 'ESTATE_ADMINISTRATOR', status: 'ACTIVE' },
      });
    }

    process.stdout.write(`Chairman ready: ${CHAIRMAN_EMAIL} / ${DEMO_PASSWORD}\n`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Chairman seed failed.'}\n`);
  process.exitCode = 1;
});
