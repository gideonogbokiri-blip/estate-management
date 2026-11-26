import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { hashAccountPassword } from '../auth/password-hash.js';
import { DEMO_PASSWORD } from './demo-credentials.js';

const CONFIRMATION = '--confirm-terra-crest';

const RESIDENT_EMAIL = 'pcr@testlancon.com';
const MANAGER_EMAIL = 'pc@testlancon.com';
const APPROVER_EMAIL = 'pca@testlancon.com';
const LANDLORD_EMAIL = 'pcl@testlancon.com';
const SECURITY_EMAIL = 'pcs@testlancon.com';

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(`Usage: npm run seed:terra-crest -- ${CONFIRMATION} [--allow-remote-demo-seed]`);
  }
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL must be configured.');
  const host = new URL(connectionString).hostname.toLowerCase();
  if (!['localhost', '127.0.0.1', '::1'].includes(host)
    && !process.argv.includes('--allow-remote-demo-seed')) {
    throw new Error('Pass --allow-remote-demo-seed to apply this to the hosted database.');
  }

  const prisma = new PrismaService();
  try {
    const estate = await prisma.estate.findFirst({ where: { status: 'ACTIVE' }, orderBy: { createdAt: 'asc' } });
    if (!estate) throw new Error('No active estate found.');
    const passwordHash = await hashAccountPassword(DEMO_PASSWORD);

    await prisma.estate.update({
      where: { id: estate.id },
      data: { name: 'Terra Crest', address: 'Emerald Living Sanctuary, Cluster Alpha-A' },
    });

    const residents = await prisma.estateProperty.findMany({
      where: { estateId: estate.id }, orderBy: { code: 'asc' }, take: 1,
    });
    const primaryProperty = residents[0];
    if (primaryProperty) {
      await prisma.estateProperty.update({
        where: { id: primaryProperty.id },
        data: { code: 'A-104', unitNumber: 'Villa Lotus 12', description: 'Villa Type A1' },
      });
    }

    const nameChanges: Array<[string, string]> = [
      [RESIDENT_EMAIL, 'Dr. Funke Adeyemi'],
      [MANAGER_EMAIL, 'Terra Crest Estate Manager'],
      [APPROVER_EMAIL, 'Terra Crest Approver'],
      [LANDLORD_EMAIL, 'Terra Crest Landlord'],
      [SECURITY_EMAIL, 'Terra Crest Security Officer'],
    ];
    for (const [email, displayName] of nameChanges) {
      await prisma.user.upsert({
        where: { emailNormalized: email },
        update: { displayName, status: 'ACTIVE', passwordHash },
        create: { emailNormalized: email, displayName, passwordHash },
      });
    }

    const resident = await prisma.user.findUnique({
      where: { emailNormalized: RESIDENT_EMAIL }, select: { id: true },
    });
    if (resident && primaryProperty) {
      await prisma.estateWallet.updateMany({
        where: { estateId: estate.id, userId: resident.id },
        data: {
          accountNumber: '0021844402',
          bankName: 'GTBank Escrow',
          accountName: 'Dr. Funke Adeyemi · PrimaryEscrow',
        },
      });
      const wallet = await prisma.estateWallet.findUnique({
        where: {
          estateId_userId_currency: {
            estateId: estate.id, userId: resident.id, currency: 'NGN',
          },
        },
        select: { id: true },
      });
      if (wallet) {
        const sums = await prisma.estateWalletTransaction.groupBy({
          by: ['type'], where: { walletId: wallet.id, status: 'posted' },
          _sum: { amount: true },
        });
        const credits = sums.find((row) => row.type === 'credit')?._sum?.amount?.toNumber() ?? 0;
        const debits = sums.find((row) => row.type === 'debit')?._sum?.amount?.toNumber() ?? 0;
        const topUp = 125000 - (credits - debits);
        if (topUp > 0) {
          const reference = `ESCROW-OPENING-${Date.now()}`;
          const journal = await prisma.ledgerJournal.create({ data: {
            estateId: estate.id, reference, sourceType: 'opening_balance',
            description: 'Terra Crest escrow opening balance', currency: 'NGN',
            status: 'posted', occurredAt: new Date(),
          }, select: { id: true } });
          await prisma.ledgerEntry.createMany({ data: [
            { journalId: journal.id, accountCode: 'PROVIDER_CLEARING:TERRA:NGN', direction: 'debit', amount: topUp, currency: 'NGN' },
            { journalId: journal.id, accountCode: `WALLET:${wallet.id}`, direction: 'credit', amount: topUp, currency: 'NGN' },
          ] });
          await prisma.estateWalletTransaction.create({ data: {
            walletId: wallet.id, estateId: estate.id, type: 'credit', amount: topUp,
            currency: 'NGN', reference, description: 'Escrow funding',
            sourceType: 'funding', status: 'posted', journalId: journal.id,
          } });
        }
      }
    }

    process.stdout.write('Terra Crest branding applied.\n');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Terra Crest seed failed.'}\n`);
  process.exitCode = 1;
});
