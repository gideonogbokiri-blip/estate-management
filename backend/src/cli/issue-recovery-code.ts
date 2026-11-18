import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { AccountLifecycleService } from '../auth/account-lifecycle.service.js';

async function main() {
  const email = (process.argv[2] ?? '').trim().toLowerCase();
  const purpose = process.argv[3] ?? 'password_reset';
  if (!email || !['email_verification', 'password_reset'].includes(purpose)) {
    throw new Error('Usage: npm run accounts:issue-code -- <account-email> <email_verification|password_reset>');
  }
  const prisma = new PrismaService();
  const lifecycle = new AccountLifecycleService(prisma);
  try {
    const user = await prisma.user.findUnique({ where: { emailNormalized: email }, select: { id: true } });
    if (!user) throw new Error('Account not found.');
    const result = await lifecycle.issue(user.id, purpose, null);
    process.stdout.write(`\n${purpose} code for ${email}: ${result.code}\nExpires: ${result.expiresAt}\nShare this code securely with the account holder. It is not stored in plain text.\n\n`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Could not issue the code.'}\n`);
  process.exitCode = 1;
});
