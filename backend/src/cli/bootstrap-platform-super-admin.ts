import 'dotenv/config';
import { PrismaService } from '../prisma/prisma.service.js';

const ROLE_KEY = 'platform_super_admin';

async function main() {
  const email = (process.argv[2] ?? '').trim().toLowerCase();
  const confirmation = process.argv[3] ?? '';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new Error('Usage: npm run bootstrap:platform-super-admin -- <account-email> GRANT_PLATFORM_SUPER_ADMIN:<account-email>');
  }
  if (confirmation !== `GRANT_PLATFORM_SUPER_ADMIN:${email}`) {
    throw new Error(`Confirm the exact account by passing GRANT_PLATFORM_SUPER_ADMIN:${email} as the second argument.`);
  }

  const prisma = new PrismaService();
  try {
    const result = await prisma.$transaction(async (tx) => {
      await tx.$queryRaw<Array<{ id: string }>>`SELECT id FROM users WHERE email_normalized = ${email} FOR UPDATE`;
      const user = await tx.user.findUnique({
        where: { emailNormalized: email },
        select: { id: true, emailNormalized: true, displayName: true, status: true },
      });
      if (!user || user.status !== 'ACTIVE') {
        throw new Error('The selected email must belong to an existing active account.');
      }

      const existing = await tx.platformRoleGrant.findUnique({
        where: { userId_roleKey: { userId: user.id, roleKey: ROLE_KEY } },
        select: { id: true },
      });
      if (existing) return { granted: false, user };

      const grantedAt = new Date();
      await tx.platformRoleGrant.create({ data: { userId: user.id, roleKey: ROLE_KEY } });
      await tx.auditEvent.create({
        data: {
          actorUserId: null,
          scope: 'platform',
          action: 'platform.role.bootstrap_granted',
          targetType: 'user',
          targetId: user.id,
          outcome: 'success',
          occurredAt: grantedAt,
          metadata: { roleKey: ROLE_KEY, email: user.emailNormalized, grantSource: 'operator_cli' },
        },
      });
      return { granted: true, user };
    }, { isolationLevel: 'Serializable' });

    if (result.granted) {
      process.stdout.write(`Granted ${ROLE_KEY} to ${result.user.displayName} (${result.user.emailNormalized}).\n`);
    } else {
      process.stdout.write(`${result.user.emailNormalized} already has ${ROLE_KEY}; no change made.\n`);
    }
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Platform super-admin bootstrap failed.'}\n`);
  process.exitCode = 1;
});
