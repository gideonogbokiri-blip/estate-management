import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { hashAccountPassword } from '../auth/password-hash.js';

async function main() {
  const prisma = new PrismaService();
  try {
    const estate = await prisma.estate.findFirst({ where: { status: 'ACTIVE' }, orderBy: { createdAt: 'asc' } });
    if (!estate) throw new Error('No active estate found.');
    const email = 'estate.approver.demo@example.test';
    const passwordHash = await hashAccountPassword('Demo-Approve-4Pt8-Rx2k');
    const user = await prisma.user.upsert({
      where: { emailNormalized: email },
      update: { status: 'ACTIVE', passwordHash },
      create: { emailNormalized: email, displayName: 'Estate Demo Approver', passwordHash },
      select: { id: true },
    });
    await prisma.estateMembership.upsert({
      where: { estateId_userId_role: { estateId: estate.id, userId: user.id, role: 'ESTATE_ADMINISTRATOR' } },
      update: { status: 'ACTIVE' },
      create: { estateId: estate.id, userId: user.id, role: 'ESTATE_ADMINISTRATOR' },
    });
    process.stdout.write(`Approver ready: ${email} / Demo-Approve-4Pt8-Rx2k\n`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Approver seed failed.'}\n`);
  process.exitCode = 1;
});
