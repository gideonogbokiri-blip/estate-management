import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';

const MANAGER_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_MANAGER', 'FINANCE_MANAGER'] as const;

@Injectable()
export class EstateDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async summary(actorUserId: string, estateId: string) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: {
        userId: actorUserId, estateId, status: 'ACTIVE', role: { in: [...MANAGER_ROLES] },
        estate: { status: 'ACTIVE' },
      },
      select: { id: true },
    });
    if (!membership) throw new ForbiddenException('Active estate management access is required.');

    const today = new Date(`${new Date().toISOString().slice(0, 10)}T00:00:00.000Z`);
    const [propertyCount, occupiedProperties, residentCount, pendingAccessRequests, activeTenancies, pendingTenancies, pendingOwnershipReviews, invoicesByCurrency] = await this.prisma.$transaction([
      this.prisma.estateProperty.count({ where: { estateId, status: { not: 'ARCHIVED' } } }),
      this.prisma.propertyOccupancy.findMany({
        where: {
          estateId, status: 'ACTIVE', effectiveFrom: { lte: today },
          OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }],
        },
        distinct: ['propertyId'],
        select: { propertyId: true },
      }),
      this.prisma.estateMembership.count({ where: { estateId, status: 'ACTIVE', role: { in: ['RESIDENT', 'LANDLORD'] } } }),
      this.prisma.estateResidentJoinRequest.count({ where: { estateId, status: 'PENDING' } }),
      this.prisma.estateTenancy.count({
        where: {
          estateId, status: 'ACTIVE', effectiveFrom: { lte: today },
          OR: [{ effectiveTo: null }, { effectiveTo: { gte: today } }],
        },
      }),
      this.prisma.estateTenancy.count({ where: { estateId, status: 'PENDING_APPROVAL' } }),
      this.prisma.estateOwnershipInterest.count({ where: { estateId, status: 'ACTIVE', verificationStatus: 'PENDING' } }),
      this.prisma.$queryRaw<Array<{ currency: string; count: number; total: string }>>`
        SELECT i.currency, COUNT(*)::int AS count,
          COALESCE(SUM(i.total - COALESCE(s.paid, 0)), 0)::text AS total
        FROM estate_invoice_drafts i
        LEFT JOIN (
          SELECT invoice_id, SUM(amount) AS paid
          FROM estate_invoice_settlements WHERE estate_id = ${estateId}::uuid
          GROUP BY invoice_id
        ) s ON s.invoice_id = i.id
        WHERE i.estate_id = ${estateId}::uuid AND i.status IN ('ISSUED', 'PARTIALLY_PAID')
        GROUP BY i.currency ORDER BY i.currency ASC
      `,
    ]);

    return {
      estateId,
      asOf: today.toISOString(),
      properties: { total: propertyCount, occupied: occupiedProperties.length, vacant: Math.max(0, propertyCount - occupiedProperties.length) },
      residents: { activeMemberships: residentCount },
      accessRequests: { pending: pendingAccessRequests },
      ownershipReviews: { pending: pendingOwnershipReviews },
      tenancies: { active: activeTenancies, pendingApproval: pendingTenancies },
      outstandingIssuedInvoices: invoicesByCurrency.map((group) => ({
        currency: group.currency,
        count: group.count,
        total: group.total,
      })),
      source: 'database',
    };
  }
}
