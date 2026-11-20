import { CanActivate, ExecutionContext, HttpException, HttpStatus, Injectable } from '@nestjs/common';

interface RequestLike {
  method?: string;
  originalUrl?: string;
  path?: string;
  ip?: string;
  headers?: Record<string, string | string[] | undefined>;
}

/**
 * Baseline in-process sliding-window rate limiter. On serverless platforms each
 * warm instance keeps its own counter, so this is a per-instance control, not a
 * distributed one. A shared store is required before treating it as a hard quota.
 */
@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly max = this.positiveEnv('RATE_LIMIT_MAX', 300);
  private readonly windowMs = this.positiveEnv('RATE_LIMIT_WINDOW_MS', 60_000);
  private readonly hits = new Map<string, number[]>();

  private positiveEnv(name: string, fallback: number) {
    const value = Number(process.env[name] ?? fallback);
    return Number.isFinite(value) && value > 0 ? Math.floor(value) : fallback;
  }

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<RequestLike>();
    const path = request.originalUrl ?? request.path ?? '/';
    if (path.startsWith('/api/v1/health/')) return true;

    const forwarded = request.headers?.['x-forwarded-for'];
    const clientIp = Array.isArray(forwarded)
      ? forwarded[0]
      : forwarded?.split(',')[0]?.trim();
    const ip = clientIp || request.ip || 'unknown';
    const route = `${request.method ?? 'GET'} ${path.split('?')[0]}`;
    const key = `${ip}|${route}`;
    const now = Date.now();
    const cutoff = now - this.windowMs;
    const recent = (this.hits.get(key) ?? []).filter((time) => time > cutoff);

    if (recent.length >= this.max) {
      throw new HttpException('Too many requests. Slow down and try again.', HttpStatus.TOO_MANY_REQUESTS);
    }
    recent.push(now);
    this.hits.set(key, recent);

    if (this.hits.size > 10_000) {
      for (const [storedKey, times] of this.hits) {
        if (times.every((time) => time <= cutoff)) this.hits.delete(storedKey);
      }
    }
    return true;
  }
}
