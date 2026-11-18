import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createHash, randomBytes } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import { hashAccountPassword } from './password-hash.js';

const SUPER_ADMIN = 'platform_super_admin';
const PURPOSES = ['email_verification', 'password_reset'] as const;

function codeHash(code: string) {
  return createHash('sha256').update(code, 'utf8').digest('hex');
}

function issueCode() {
  return randomBytes(6).toString('base64url').toUpperCase().replace(/[^A-Z0-9]/g, 'A').slice(0, 8);
}

@Injectable()
export class AccountLifecycleService {
  constructor(private readonly prisma: PrismaService) {}

  async issue(userId: string, purpose: string, actorUserId: string | null) {
    if (!(PURPOSES as readonly string[]).includes(purpose)) {
      throw new BadRequestException('Unsupported account lifecycle purpose.');
    }
    if (actorUserId) {
      const grant = await this.prisma.platformRoleGrant.findUnique({
        where: { userId_roleKey: { userId: actorUserId, roleKey: SUPER_ADMIN } },
        select: { id: true },
      });
      if (!grant) throw new ForbiddenException('Only a platform super administrator can issue account codes.');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: userId }, select: { id: true, status: true },
    });
    if (!user) throw new NotFoundException('Account not found.');
    if (user.status !== 'ACTIVE') throw new BadRequestException('Only active accounts can receive a code.');

    const code = issueCode();
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000);
    const record = await this.prisma.accountRecoveryCode.create({ data: {
      userId, purpose, codeHash: codeHash(code), expiresAt, createdByUserId: actorUserId,
    }, select: { id: true } });
    await this.prisma.auditEvent.create({ data: {
      actorUserId, scope: 'platform', action: 'account.recovery_code_issued',
      targetType: 'account_recovery_code', targetId: record.id, outcome: 'success',
      occurredAt: new Date(), metadata: { purpose, userId },
    } });
    return { code, purpose, expiresAt: expiresAt.toISOString(), userId };
  }

  async confirm(email: string, code: string, newPassword?: string) {
    const user = await this.prisma.user.findUnique({
      where: { emailNormalized: email.trim().toLowerCase() },
      select: { id: true, status: true, emailVerifiedAt: true },
    });
    if (!user || user.status !== 'ACTIVE') throw new BadRequestException('The code is invalid or expired.');
    const record = await this.prisma.accountRecoveryCode.findFirst({
      where: { userId: user.id, codeHash: codeHash(code.trim().toUpperCase()), usedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
      select: { id: true, purpose: true },
    });
    if (!record) throw new BadRequestException('The code is invalid or expired.');

    const now = new Date();
    if (record.purpose === 'password_reset') {
      if (!newPassword || newPassword.length < 12 || newPassword.length > 128) {
        throw new BadRequestException('A new password of 12 to 128 characters is required.');
      }
      const passwordHash = await hashAccountPassword(newPassword);
      await this.prisma.$transaction([
        this.prisma.user.update({ where: { id: user.id }, data: { passwordHash } }),
        this.prisma.userSession.updateMany({
          where: { userId: user.id, revokedAt: null }, data: { revokedAt: now },
        }),
        this.prisma.accountRecoveryCode.update({ where: { id: record.id }, data: { usedAt: now } }),
        this.prisma.auditEvent.create({ data: {
          actorUserId: user.id, scope: 'platform', action: 'account.password_reset',
          targetType: 'user', targetId: user.id, outcome: 'success', occurredAt: now,
        } }),
      ]);
      return { confirmed: true, purpose: 'password_reset' };
    }

    await this.prisma.$transaction([
      this.prisma.user.update({ where: { id: user.id }, data: { emailVerifiedAt: user.emailVerifiedAt ?? now } }),
      this.prisma.accountRecoveryCode.update({ where: { id: record.id }, data: { usedAt: now } }),
      this.prisma.auditEvent.create({ data: {
        actorUserId: user.id, scope: 'platform', action: 'account.email_verified',
        targetType: 'user', targetId: user.id, outcome: 'success', occurredAt: now,
      } }),
    ]);
    return { confirmed: true, purpose: 'email_verification' };
  }
}
