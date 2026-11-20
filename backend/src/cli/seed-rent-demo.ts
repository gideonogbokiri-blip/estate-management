import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { DEMO_ESTATE_PREFIX, demoEmails, estateInitials } from './demo-credentials.js';

const TENANCY_ID = 'a1000000-0000-4000-8000-000000000001';

async function main() {
  const prisma = new PrismaService();
  try {
    const estate = await prisma.estate.findFirst({ where: { status: 'ACTIVE' }, orderBy: { createdAt: 'asc' } });
    if (!estate) throw new Error('No active estate found.');
    const property = await prisma.estateProperty.findFirst({
      where: { estateId: estate.id, code: 'PC-001' },
      select: { id: true },
    });
    if (!property) throw new Error('Demo property PC-001 not found.');

    const demo = demoEmails(estateInitials(estate.name));
    const users = await prisma.user.findMany({
      where: {
        emailNormalized: {
          in: [demo.resident, demo.landlord, demo.manager, ...Object.values(demoEmails(DEMO_ESTATE_PREFIX))],
        },
      },
      select: { id: true, emailNormalized: true },
    });
    const find = (...candidates: string[]) => {
      const user = candidates.map((email) => users.find((item) => item.emailNormalized === email)).find(Boolean);
      if (!user) throw new Error(`Demo user not found: ${candidates.join(', ')}`);
      return user.id;
    };

    const tenantUserId = find(demo.resident, demoEmails(DEMO_ESTATE_PREFIX).resident);
    const payeeUserId = find(demo.landlord, demoEmails(DEMO_ESTATE_PREFIX).landlord);
    const managerId = find(demo.manager, demoEmails(DEMO_ESTATE_PREFIX).manager);

    await prisma.estateTenancy.upsert({
      where: { id: TENANCY_ID },
      update: {
        status: 'ACTIVE',
        rentAmount: 50000,
        currency: 'NGN',
        rentFrequency: 'MONTHLY',
        rentDueDay: 1,
        effectiveFrom: new Date('2026-01-01T00:00:00.000Z'),
        effectiveTo: null,
        approvedById: managerId,
        approvedAt: new Date(),
      },
      create: {
        id: TENANCY_ID,
        estateId: estate.id,
        propertyId: property.id,
        tenantUserId,
        payeeUserId,
        status: 'ACTIVE',
        rentAmount: 50000,
        currency: 'NGN',
        rentFrequency: 'MONTHLY',
        rentDueDay: 1,
        effectiveFrom: new Date('2026-01-01T00:00:00.000Z'),
        createdById: managerId,
        approvedById: managerId,
        approvedAt: new Date(),
        termsNote: 'Demo tenancy for rent engine walkthrough (no real tenancy).',
      },
    });
    process.stdout.write(`Demo tenancy ready: ${TENANCY_ID}\n`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Rent seed failed.'}\n`);
  process.exitCode = 1;
});
