import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import {
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from 'node:crypto';
import { hashAccountPassword, verifyAccountPassword } from './password-hash.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { AccountStatus } from '../generated/prisma/client.js';
import type { Prisma } from '../generated/prisma/client.js';

const ACCESS_TOKEN_LIFETIME_SECONDS = 15 * 60;
const REFRESH_TOKEN_LIFETIME_MS = 30 * 24 * 60 * 60 * 1000;

type AccessClaims = {
  sub: string;
  sid: string;
  iat: number;
  exp: number;
};

@Injectable()
export class AuthService {
  private readonly accessSecret: Buffer;

  constructor(private readonly prisma: PrismaService) {
    const secret = process.env.ACCESS_TOKEN_SECRET;
    if (!secret || Buffer.byteLength(secret) < 32) {
      throw new Error('ACCESS_TOKEN_SECRET must contain at least 32 bytes.');
    }
    this.accessSecret = Buffer.from(secret, 'utf8');
  }

  async register(input: {
    email: string;
    displayName: string;
    password: string;
  }) {
    const emailNormalized = input.email.trim().toLowerCase();
    const passwordHash = await hashAccountPassword(input.password);
    try {
      const user = await this.prisma.$transaction(async (tx) => {
        const created = await tx.user.create({
          data: {
            emailNormalized,
            displayName: input.displayName.trim(),
            passwordHash,
          },
          select: { id: true, emailNormalized: true, displayName: true },
        });
        await tx.auditEvent.create({
          data: {
            actorUserId: created.id,
            scope: 'platform',
            action: 'account.registered',
            targetType: 'user',
            targetId: created.id,
            outcome: 'success',
            occurredAt: new Date(),
          },
        });
        return created;
      });
      return { user };
    } catch (error) {
      if (this.isUniqueConstraintError(error)) {
        throw new ConflictException({
          code: 'ACCOUNT_EXISTS',
          message: 'An account with this email already exists.',
        });
      }
      throw error;
    }
  }

  async login(input: { email: string; password: string }) {
    const emailNormalized = input.email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { emailNormalized },
    });
    if (!user || user.status !== AccountStatus.ACTIVE) {
      throw new UnauthorizedException({
        code: 'INVALID_CREDENTIALS',
        message: 'Email or password is incorrect.',
      });
    }
    const validPassword = await verifyAccountPassword(input.password, user.passwordHash);
    if (!validPassword) {
      throw new UnauthorizedException({
        code: 'INVALID_CREDENTIALS',
        message: 'Email or password is incorrect.',
      });
    }
    const session = await this.createSession(user.id);
    return {
      user: { id: user.id, email: user.emailNormalized, displayName: user.displayName },
      ...session,
    };
  }

  async refresh(refreshToken: string) {
    const tokenHash = this.hashOpaqueToken(refreshToken);
    const now = new Date();
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.userSession.findUnique({
        where: { refreshTokenHash: tokenHash },
        include: { user: true },
      });
      if (
        !existing ||
        existing.revokedAt ||
        existing.expiresAt <= now ||
        existing.user.status !== AccountStatus.ACTIVE
      ) {
        throw new UnauthorizedException({
          code: 'INVALID_REFRESH_TOKEN',
          message: 'Refresh session is invalid or expired.',
        });
      }

      const revoked = await tx.userSession.updateMany({
        where: { id: existing.id, revokedAt: null },
        data: { revokedAt: now },
      });
      if (revoked.count !== 1) {
        throw new UnauthorizedException({
          code: 'INVALID_REFRESH_TOKEN',
          message: 'Refresh session has already been used.',
        });
      }

      const nextSession = await this.insertSession(tx, existing.userId, existing.id);
      return {
        user: {
          id: existing.user.id,
          email: existing.user.emailNormalized,
          displayName: existing.user.displayName,
        },
        ...nextSession,
      };
    });
  }

  async revokeSession(sessionId: string, userId: string): Promise<void> {
    await this.prisma.userSession.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async readCurrentUser(userId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, status: AccountStatus.ACTIVE },
      select: { id: true, emailNormalized: true, displayName: true, phone: true },
    });
    if (!user) throw new UnauthorizedException();
    return {
      id: user.id,
      email: user.emailNormalized,
      displayName: user.displayName,
      phone: user.phone,
    };
  }

  verifyAccessToken(token: string): { userId: string; sessionId: string } {
    if (token.length > 4096) throw new Error('Invalid token.');
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error('Invalid token.');
    const [headerPart, payloadPart, signaturePart] = parts;
    const expectedSignature = this.sign(`${headerPart}.${payloadPart}`);
    const provided = Buffer.from(signaturePart, 'base64url');
    const expected = Buffer.from(expectedSignature, 'base64url');
    if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) {
      throw new Error('Invalid signature.');
    }
    const header = JSON.parse(Buffer.from(headerPart, 'base64url').toString('utf8')) as {
      alg?: string;
      typ?: string;
    };
    const claims = JSON.parse(Buffer.from(payloadPart, 'base64url').toString('utf8')) as AccessClaims;
    const now = Math.floor(Date.now() / 1000);
    if (
      header.alg !== 'HS256' ||
      header.typ !== 'JWT' ||
      typeof claims.sub !== 'string' ||
      typeof claims.sid !== 'string' ||
      !Number.isSafeInteger(claims.exp) ||
      claims.exp <= now
    ) {
      throw new Error('Invalid claims.');
    }
    return { userId: claims.sub, sessionId: claims.sid };
  }

  private async createSession(userId: string) {
    return this.prisma.$transaction((tx) => this.insertSession(tx, userId));
  }

  private async insertSession(
    tx: Prisma.TransactionClient,
    userId: string,
    rotatedFromId?: string,
  ) {
    const refreshToken = randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_LIFETIME_MS);
    const session = await tx.userSession.create({
      data: {
        userId,
        refreshTokenHash: this.hashOpaqueToken(refreshToken),
        expiresAt,
        rotatedFromId,
      },
      select: { id: true },
    });
    return {
      accessToken: this.issueAccessToken(userId, session.id),
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: ACCESS_TOKEN_LIFETIME_SECONDS,
    };
  }

  private issueAccessToken(userId: string, sessionId: string): string {
    const issuedAt = Math.floor(Date.now() / 1000);
    const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(
      JSON.stringify({
        sub: userId,
        sid: sessionId,
        iat: issuedAt,
        exp: issuedAt + ACCESS_TOKEN_LIFETIME_SECONDS,
      }),
    ).toString('base64url');
    const content = `${header}.${payload}`;
    return `${content}.${this.sign(content)}`;
  }

  private sign(value: string): string {
    return createHmac('sha256', this.accessSecret).update(value).digest('base64url');
  }

  private hashOpaqueToken(value: string): string {
    return createHash('sha256').update(value).digest('hex');
  }

  private isUniqueConstraintError(error: unknown): boolean {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      (error as { code?: string }).code === 'P2002'
    );
  }
}
