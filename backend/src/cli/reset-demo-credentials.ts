import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { hashAccountPassword } from '../auth/password-hash.js';
import { DEMO_PASSWORD, demoEmails, estateInitials } from './demo-credentials.js';

const CONFIRMATION = '--confirm-reset-demo-credentials';

const LEGACY = {
  manager: 'estate.manager.demo@example.test',
  approver: 'estate.approver.demo@example.test',
  resident: 'estate.resident.demo@example.test',
  landlord: 'estate.landlord.demo@example.test',
  security: 'estate.security.demo@example.test',
  applicant: 'estate.applicant.demo@example.test',
  platform: 'estate.platform.demo@example.test',
} as const;

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(`Usage: npm run demo:reset-credentials -- ${CONFIRMATION} [--allow-remote-demo-seed]`);
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL must be configured.');
  const host = new URL(connectionString).hostname.toLowerCase();
  if (!['localhost', '127.0.0.1', '::1'].includes(host)
    && !process.argv.includes('--allow-remote-demo-seed')) {
    throw new Error('Pass --allow-remote-demo-seed to update the hosted demo database.');
  }

  const prisma = new PrismaService();
  try {
    const estate = await prisma.estate.findFirst({ where: { status: 'ACTIVE' }, orderBy: { createdAt: 'asc' } });
    if (!estate) throw new Error('No active estate found to derive the email prefix.');
    const emails = demoEmails(estateInitials(estate.name));
    const passwordHash = await hashAccountPassword(DEMO_PASSWORD);

    for (const role of Object.keys(LEGACY) as Array<keyof typeof LEGACY>) {
      const oldEmail = LEGACY[role];
      const newEmail = emails[role];
      const existingByOld = await prisma.user.findUnique({ where: { emailNormalized: oldEmail }, select: { id: true } });
      const existingByNew = await prisma.user.findUnique({ where: { emailNormalized: newEmail }, select: { id: true } });
      if (existingByOld && existingByNew && existingByOld.id !== existingByNew.id) {
        throw new Error(`Both ${oldEmail} and ${newEmail} exist; resolve the conflict manually.`);
      }
      const userId = existingByNew?.id ?? existingByOld?.id;
      if (!userId) {
        process.stdout.write(`Skipped (not found): ${oldEmail} -> ${newEmail}\n`);
        continue;
      }
      await prisma.user.update({
        where: { id: userId },
        data: { emailNormalized: newEmail, passwordHash, status: 'ACTIVE' },
      });
      process.stdout.write(`Ready: ${newEmail} / ${DEMO_PASSWORD}\n`);
    }
    process.stdout.write(`Estate prefix: ${estateInitials(estate.name)}\n`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Reset failed.'}\n`);
  process.exitCode = 1;
});
