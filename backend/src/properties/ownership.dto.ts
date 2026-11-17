import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min, Matches } from 'class-validator';

const OWNERSHIP_STATUSES = ['active', 'ended'] as const;
const OWNERSHIP_VERIFICATION_STATUSES = ['pending', 'verified', 'rejected'] as const;

export class OwnershipQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page = 1;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  pageSize = 25;

  @IsOptional() @IsIn(OWNERSHIP_STATUSES)
  status?: (typeof OWNERSHIP_STATUSES)[number];

  @IsOptional() @IsIn(OWNERSHIP_VERIFICATION_STATUSES)
  verificationStatus?: (typeof OWNERSHIP_VERIFICATION_STATUSES)[number];
}

export class CreateOwnershipInterestDto {
  @IsString() @MaxLength(254) @Matches(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  ownerEmail!: string;

  @IsString() @MaxLength(6) @Matches(/^(?:0|[1-9]\d{0,2})(?:\.\d{1,2})?$/)
  ownershipShare!: string;

  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/)
  effectiveFrom!: string;

  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/)
  effectiveTo?: string | null;

  @IsString() @MaxLength(1000)
  evidenceNote!: string;
}

export class DecideOwnershipVerificationDto {
  @IsIn(['verify', 'reject'])
  decision!: 'verify' | 'reject';

  @IsString() @MaxLength(1000)
  reason!: string;
}

export class EndOwnershipInterestDto {
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/)
  effectiveTo!: string;

  @IsString() @MaxLength(1000)
  reason!: string;
}
