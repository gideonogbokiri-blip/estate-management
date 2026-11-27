import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma, type EstateRole } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';

const MANAGEMENT_ROLES: EstateRole[] = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER', 'FINANCE_MANAGER'];

@Injectable()
export class ManagerResidentsService {
  constructor(private readonly prisma: PrismaService) {}

  private async requireManager(actorUserId: string, estateId: string) {
    const membership = await this.prisma.estateMembership.findFirst({
      where: {
        userId: actorUserId, estateId, status: 'ACTIVE', estate: { status: 'ACTIVE' },
        role: { in: MANAGEMENT_ROLES },
      },
      select: { role: true },
    });
    if (!membership) throw new ForbiddenException('Active estate management access is required.');
  }

  async listResidents(actorUserId: string, estateId: string) {
    await this.requireManager(actorUserId, estateId);

    const memberships = await this.prisma.estateMembership.findMany({
      where: { estateId, role: 'RESIDENT' },
      select: { userId: true, status: true },
      orderBy: { userId: 'asc' },
      take: 500,
    });
    const residents = await this.prisma.user.findMany({
      where: { id: { in: memberships.map((item) => item.userId) } },
      select: { id: true, displayName: true, emailNormalized: true },
    });
    const userById = new Map(residents.map((user) => [user.id, user]));

    const [occupancies, tenancies, ownerships, properties] = await Promise.all([
      this.prisma.propertyOccupancy.findMany({
        where: { estateId },
        select: { residentId: true, propertyId: true, relationship: true, status: true, effectiveFrom: true, effectiveTo: true },
      }),
      this.prisma.estateTenancy.findMany({
        where: { estateId },
        select: { tenantUserId: true, payeeUserId: true, propertyId: true, status: true, rentAmount: true, currency: true, effectiveFrom: true, effectiveTo: true },
      }),
      this.prisma.estateOwnershipInterest.findMany({
        where: { estateId, status: 'ACTIVE', verificationStatus: 'VERIFIED' },
        select: { ownerUserId: true, propertyId: true, ownershipShare: true },
      }),
      this.prisma.estateProperty.findMany({
        where: { estateId }, select: { id: true, code: true, unitNumber: true, propertyType: true },
      }),
    ]);
    const propertyById = new Map(properties.map((property) => [property.id, property]));
    const payeeIds = [...new Set(tenancies.map((tenancy) => tenancy.payeeUserId))];
    const payees = await this.prisma.user.findMany({
      where: { id: { in: payeeIds } }, select: { id: true, displayName: true },
    });
    const payeeName = new Map(payees.map((user) => [user.id, user.displayName]));

    return {
      items: memberships.map((membership) => {
        const user = userById.get(membership.userId);
        const occupied = occupancies.filter((item) => item.residentId === membership.userId);
        const tenancy = tenancies.find((item) => item.tenantUserId === membership.userId);
        const ownership = ownerships.find((item) => item.ownerUserId === membership.userId);
        const property = occupied[0] ?? tenancy ?? ownership;
        const prop = property ? propertyById.get(property.propertyId) : null;
        return {
          userId: membership.userId,
          name: user?.displayName ?? 'Resident',
          email: user?.emailNormalized ?? '',
          accessStatus: membership.status.toLowerCase(),
          propertyId: prop?.id ?? null,
          propertyCode: prop?.code ?? null,
          unitNumber: prop?.unitNumber ?? null,
          relationship: ownership ? 'OWNER' : tenancy ? 'TENANT' : occupied[0]?.relationship ?? 'RESIDENT',
          landlordName: tenancy ? payeeName.get(tenancy.payeeUserId) ?? 'Landlord' : null,
          rent: tenancy
            ? `${tenancy.currency} ${tenancy.rentAmount.toString()}`
            : null,
        };
      }),
    };
  }

  async residentHistory(actorUserId: string, estateId: string, residentUserId: string) {
    await this.requireManager(actorUserId, estateId);
    const resident = await this.prisma.user.findFirst({
      where: { id: residentUserId }, select: { id: true, displayName: true, emailNormalized: true },
    });
    if (!resident) throw new ForbiddenException('Resident not found.');
    const membership = await this.prisma.estateMembership.findFirst({
      where: { estateId, userId: residentUserId }, select: { status: true },
    });
    if (!membership) throw new ForbiddenException('This resident is not linked to the estate.');

    const [invoices, walletTransactions, rentPayments, serviceOrders, household] = await Promise.all([
      this.prisma.estateInvoiceDraft.findMany({
        where: { estateId, payerUserId: residentUserId },
        select: {
          id: true, invoiceNumber: true, status: true, total: true, currency: true,
          dueDate: true, createdAt: true,
          settlements: { select: { amount: true, receivedAt: true, receiptNumber: true } },
        },
        orderBy: { createdAt: 'desc' }, take: 100,
      }),
      this.prisma.estateWalletTransaction.findMany({
        where: { estateId, wallet: { userId: residentUserId } },
        select: { id: true, type: true, amount: true, currency: true, description: true, reference: true, createdAt: true },
        orderBy: { createdAt: 'desc' }, take: 100,
      }),
      this.prisma.rentPayment.findMany({
        where: { estateId, paidBy: residentUserId },
        select: { id: true, amount: true, currency: true, receiptNumber: true, receivedAt: true },
        orderBy: { receivedAt: 'desc' }, take: 100,
      }),
      this.prisma.estateServiceOrder.findMany({
        where: { estateId, orderedBy: residentUserId },
        select: { id: true, amount: true, currency: true, status: true, provider: true, fulfilmentCode: true, createdAt: true },
        orderBy: { createdAt: 'desc' }, take: 100,
      }),
      this.prisma.householdMember.findMany({
        where: { estateId, primaryUserId: residentUserId },
        select: { id: true, fullName: true, relationship: true, memberType: true, status: true },
        take: 50,
      }),
    ]);

    return {
      resident: {
        id: resident.id, name: resident.displayName, email: resident.emailNormalized,
        accessStatus: membership.status.toLowerCase(),
      },
      invoices: invoices.map((invoice) => ({
        id: invoice.id, reference: invoice.invoiceNumber, status: invoice.status.toLowerCase(),
        amount: invoice.total.toString(), currency: invoice.currency,
        balance: invoice.total.minus(
          invoice.settlements.reduce((sum, item) => sum.plus(item.amount), new Prisma.Decimal(0)),
        ).toString(),
        dueDate: invoice.dueDate.toISOString().slice(0, 10),
        receipts: invoice.settlements.map((item) => item.receiptNumber),
      })),
      wallet: walletTransactions.map((tx) => ({
        id: tx.id, type: tx.type, amount: tx.amount.toString(), currency: tx.currency,
        description: tx.description, reference: tx.reference,
        date: tx.createdAt.toISOString(),
      })),
      rent: rentPayments.map((payment) => ({
        id: payment.id, amount: payment.amount.toString(), currency: payment.currency,
        receipt: payment.receiptNumber, date: payment.receivedAt.toISOString(),
      })),
      services: serviceOrders.map((order) => ({
        id: order.id, amount: order.amount.toString(), currency: order.currency,
        status: order.status.toLowerCase(), provider: order.provider,
        voucher: order.fulfilmentCode, date: order.createdAt.toISOString(),
      })),
      household: household.map((member) => ({
        id: member.id, name: member.fullName, relationship: member.relationship,
        type: member.memberType, status: member.status.toLowerCase(),
      })),
    };
  }
}

