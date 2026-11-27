import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { EstateRole, Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { UpdateEstateSettingsDto } from './estate-settings.dto.js';

const VIEW_ROLES = ['ESTATE_ADMINISTRATOR', 'ESTATE_CHAIRMAN', 'ESTATE_MANAGER'] as const;

@Injectable()
export class EstateSettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async read(actorUserId: string, estateId: string) {
    await this.requireMembership(actorUserId, estateId, VIEW_ROLES);
    const estate = await this.prisma.estate.findFirst({
      where: { id: estateId, status: 'ACTIVE' },
      select: { id: true, estateCode: true, name: true, estateType: true, address: true, state: true, lga: true, status: true, updatedAt: true },
    });
    if (!estate) throw new NotFoundException('Active estate not found.');
    return estate;
  }

  async update(actorUserId: string, estateId: string, input: UpdateEstateSettingsDto) {
    const now = new Date();
    const values = {
      name: input.name.trim(),
      estateType: input.estateType.trim(),
      address: input.address.trim(),
      state: input.state.trim(),
      lga: input.lga.trim(),
    };
    if (Object.values(values).some((value) => value.length < 2)) {
      throw new BadRequestException('Estate settings fields must contain at least two characters.');
    }
    return this.prisma.$transaction(async (tx) => {
      await this.requireMembership(actorUserId, estateId, ['ESTATE_ADMINISTRATOR'], tx);
      const before = await tx.estate.findFirst({
        where: { id: estateId, status: 'ACTIVE' },
        select: { id: true, estateCode: true, name: true, estateType: true, address: true, state: true, lga: true },
      });
      if (!before) throw new NotFoundException('Active estate not found.');
      const after = await tx.estate.update({ where: { id: estateId }, data: values, select: { id: true, estateCode: true, name: true, estateType: true, address: true, state: true, lga: true, status: true, updatedAt: true } });
      await tx.auditEvent.create({ data: {
        actorUserId, scope: 'estate', estateId, action: 'estate.settings_updated', targetType: 'estate', targetId: estateId, outcome: 'success', occurredAt: now,
        metadata: { changedFields: Object.keys(values).filter((key) => before[key as keyof typeof values] !== values[key as keyof typeof values]) },
      } });
      return after;
    });
  }

  private async requireMembership(actorUserId: string, estateId: string, roles: readonly EstateRole[], tx: Prisma.TransactionClient | PrismaService = this.prisma) {
    const membership = await tx.estateMembership.findFirst({ where: { userId: actorUserId, estateId, status: 'ACTIVE', role: { in: [...roles] }, estate: { status: 'ACTIVE' } }, select: { id: true } });
    if (!membership) throw new ForbiddenException('Active estate settings access is required.');
    return membership;
  }
}

