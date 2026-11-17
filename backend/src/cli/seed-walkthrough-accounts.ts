import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { hashAccountPassword } from '../auth/password-hash.js';

const CONFIRMATION = '--confirm-walkthrough-accounts';

const ACCOUNTS = [
  {
    email: 'estate.applicant.demo@example.test',
    displayName: 'Estate Applicant (Demo)',
    password: 'Demo-Apply-5Nm8-Vt2q',
  },
  {
    email: 'estate.platform.demo@example.test',
    displayName: 'Estate Platform Reviewer (Demo)',
    password: 'Demo-Review-7Kp4-nQ8v',
    platformRole: 'platform_super_admin',
  },
  {
    email: 'estate.security.demo@example.test',
    displayName: 'Estate Demo Security Officer',
    password: 'Demo-Gate-6Qm2-Vr8w',
  },
];

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(`Usage: npm run seed:walkthrough-accounts -- ${CONFIRMATION}`);
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Demo account seeding is disabled when NODE_ENV is production.');
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL must be configured.');
  const host = new URL(connectionString).hostname.toLowerCase();
  if (!['localhost', '127.0.0.1', '::1'].includes(host)
    && !process.argv.includes('--allow-remote-demo-seed')) {
    throw new Error('Pass --allow-remote-demo-seed to seed a fresh hosted demo database.');
  }

  const prisma = new PrismaService();
  try {
    for (const account of ACCOUNTS) {
      const passwordHash = await hashAccountPassword(account.password);
      const user = await prisma.user.upsert({
        where: { emailNormalized: account.email },
        update: { status: 'ACTIVE', displayName: account.displayName, passwordHash },
        create: { emailNormalized: account.email, displayName: account.displayName, passwordHash },
        select: { id: true, emailNormalized: true },
      });
      if (account.platformRole) {
        await prisma.platformRoleGrant.upsert({
          where: { userId_roleKey: { userId: user.id, roleKey: account.platformRole } },
          update: {},
          create: { userId: user.id, roleKey: account.platformRole },
        });
      }
      process.stdout.write(`Ready: ${user.emailNormalized}\n`);
    }
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Walkthrough account seed failed.'}\n`);
  process.exitCode = 1;
});
