import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';

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

    const emails = [
      'estate.resident.demo@example.test',
      'estate.landlord.demo@example.test',
      'estate.manager.demo@example.test',
    ];
    const users = await prisma.user.findMany({
      where: { emailNormalized: { in: emails } },
      select: { id: true, emailNormalized: true },
    });
    const find = (email: string) => {
      const user = users.find((item) => item.emailNormalized === email);
      if (!user) throw new Error(`Demo user ${email} not found.`);
      return user.id;
    };

    const tenantUserId = find('estate.resident.demo@example.test');
    const payeeUserId = find('estate.landlord.demo@example.test');
    const managerId = find('estate.manager.demo@example.test');

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
