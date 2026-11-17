import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class HealthService {
  constructor(private readonly prisma: PrismaService) {}

  async readiness() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { status: 'ready', dependencies: { database: 'ok' } };
    } catch {
      throw new ServiceUnavailableException({
        status: 'not_ready',
        dependencies: { database: 'unavailable' },
      });
    }
  }
}
