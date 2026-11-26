import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';

const CONFIRMATION = '--confirm-clean-terra-data';

async function main() {
  if (!process.argv.includes(CONFIRMATION)) {
    throw new Error(`Usage: npm run terra:clean-data -- ${CONFIRMATION} [--allow-remote-demo-seed]`);
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

    const charges = await prisma.estateChargeVersion.findMany({
      where: { charge: { estateId: estate.id } },
      select: { id: true, name: true, description: true },
    });
    for (const charge of charges) {
      await prisma.estateChargeVersion.update({
        where: { id: charge.id },
        data: {
          name: charge.name.replace(/\s*\(demo\)/gi, '').trim(),
          description: charge.description?.replace(/\s*\(demo\)/gi, '').trim() ?? null,
        },
      });
    }

    const invoices = await prisma.estateInvoiceDraft.findMany({
      where: { estateId: estate.id },
      select: { id: true, lineSnapshot: true },
    });
    for (const invoice of invoices) {
      let snapshot = invoice.lineSnapshot;
      if (Array.isArray(snapshot)) {
        snapshot = snapshot.map((line: any) => ({
          ...line,
          description: String(line.description ?? '').replace(/\s*\(demo\)/gi, '').trim(),
        }));
      }
      await prisma.estateInvoiceDraft.update({
        where: { id: invoice.id },
        data: { lineSnapshot: snapshot as never },
      });
    }

    const services = await prisma.estateServiceDefinition.findMany({
      where: { estateId: estate.id },
      select: { id: true, name: true, description: true },
    });
    for (const service of services) {
      await prisma.estateServiceDefinition.update({
        where: { id: service.id },
        data: {
          name: service.name.replace(/\s*\(demo\)/gi, '').trim(),
          description: service.description?.replace(/\s*\(demo\)/gi, '').trim() ?? null,
        },
      });
    }

    const wallets = await prisma.estateWallet.findMany({
      where: { estateId: estate.id },
      select: { id: true, bankName: true, accountName: true },
    });
    for (const wallet of wallets) {
      await prisma.estateWallet.update({
        where: { id: wallet.id },
        data: {
          bankName: wallet.bankName?.replace(/Demo Bank/gi, 'Escrow Bank').trim() ?? null,
          accountName: wallet.accountName?.replace(/\s*\(Demo\)/gi, '').trim() ?? null,
        },
      });
    }

    await prisma.estateWalletTransaction.updateMany({
      where: { estateId: estate.id, description: { contains: 'Demo funding (no real money)' } },
      data: { description: 'Escrow funding' },
    });

    await prisma.estateServiceOrder.updateMany({
      where: { estateId: estate.id, provider: 'demo' },
      data: { provider: 'LANCON Services' },
    });
    await prisma.estateServiceOrder.updateMany({
      where: { estateId: estate.id, fulfilmentCode: { startsWith: 'DEMO-VOUCHER-' } },
      data: { fulfilmentCode: null },
    });

    process.stdout.write('Demo wording removed from live estate data.\n');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Cleanup failed.'}\n`);
  process.exitCode = 1;
});
