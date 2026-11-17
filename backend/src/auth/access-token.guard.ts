import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { AuthService } from './auth.service.js';

export type AuthenticatedRequest = Request & {
  actor: { userId: string; sessionId: string };
};

@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const header = request.headers.authorization;
    const match = header?.match(/^Bearer\s+(.+)$/i);
    if (!match) throw new UnauthorizedException();

    try {
      request.actor = this.auth.verifyAccessToken(match[1]);
      return true;
    } catch {
      throw new UnauthorizedException();
    }
  }
}
