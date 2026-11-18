import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';

const LIMIT = 50;

async function main() {
  const smtpHost = process.env.SMTP_HOST;
  const smtpFrom = process.env.SMTP_FROM;
  const prisma = new PrismaService();
  try {
    const pending = await prisma.estateNotificationDelivery.findMany({
      where: { status: 'pending' },
      include: { notification: true },
      orderBy: { createdAt: 'asc' },
      take: LIMIT,
    });
    if (!pending.length) {
      process.stdout.write('No pending notification deliveries.\n');
      return;
    }

    if (!smtpHost || !smtpFrom) {
      const result = await prisma.estateNotificationDelivery.updateMany({
        where: { id: { in: pending.map((item) => item.id) }, status: 'pending' },
        data: { status: 'skipped', lastError: 'smtp_not_configured' },
      });
      process.stdout.write(`${result.count} delivery record(s) marked skipped: SMTP is not configured.\n`);
      return;
    }

    const nodemailer = await import('nodemailer');
    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: Number(process.env.SMTP_PORT ?? 587),
      secure: (process.env.SMTP_PORT ?? '587') === '465',
      auth: process.env.SMTP_USER
        ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS ?? '' }
        : undefined,
    });

    let sent = 0;
    let failed = 0;
    for (const delivery of pending) {
      if (!delivery.recipientEmail) {
        await prisma.estateNotificationDelivery.update({ where: { id: delivery.id },
          data: { status: 'failed', attempts: { increment: 1 }, lastError: 'missing_recipient_email' } });
        failed += 1;
        continue;
      }
      try {
        await transporter.sendMail({
          from: smtpFrom,
          to: delivery.recipientEmail,
          subject: delivery.notification.title,
          text: `${delivery.notification.message}\n\nEstate: ${delivery.estateId}`,
        });
        await prisma.estateNotificationDelivery.update({ where: { id: delivery.id },
          data: { status: 'sent', attempts: { increment: 1 }, sentAt: new Date(), lastError: null } });
        sent += 1;
      } catch (error) {
        await prisma.estateNotificationDelivery.update({ where: { id: delivery.id },
          data: { status: 'failed', attempts: { increment: 1 }, lastError: String(error).slice(0, 500) } });
        failed += 1;
      }
    }
    process.stdout.write(`Notification delivery finished: ${sent} sent, ${failed} failed.\n`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Notification delivery failed.'}\n`);
  process.exitCode = 1;
});
