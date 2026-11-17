import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

@Injectable()
export class TenantAccessService {
  constructor(private readonly prisma: PrismaService) {}

  async listMine(actorUserId: string) {
    const today = new Date(`${new Date().toISOString().slice(0, 10)}T00:00:00.000Z`);
    const records = await this.prisma.estateTenancy.findMany({
      where: {
        tenantUserId: actorUserId,
        status: 'ACTIVE',
        effectiveFrom: { lte: today },
        OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }],
        estate: { status: 'ACTIVE' },
        property: { status: { not: 'ARCHIVED' } },
      },
      include: {
        estate: { select: { id: true, name: true, estateCode: true, address: true, state: true } },
        property: { select: { id: true, code: true, propertyType: true, unitNumber: true, address: true } },
        payee: { select: { displayName: true } },
      },
      orderBy: [{ effectiveFrom: 'desc' }, { createdAt: 'desc' }],
      take: 100,
    });
    return {
      items: records.map((record) => ({
        id: record.id,
        estate: record.estate,
        property: record.property,
        landlordDisplayName: record.payee.displayName,
        rent: {
          amount: record.rentAmount.toFixed(2), currency: record.currency,
          frequency: record.rentFrequency.toLowerCase(), dueDay: record.rentDueDay,
        },
        depositAmount: record.depositAmount?.toFixed(2) ?? null,
        effectiveFrom: record.effectiveFrom.toISOString().slice(0, 10),
        effectiveTo: record.effectiveTo?.toISOString().slice(0, 10) ?? null,
      })),
    };
  }
}
