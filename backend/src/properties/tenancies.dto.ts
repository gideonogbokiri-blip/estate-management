import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';

const TENANCY_STATUSES = ['pending_approval', 'active', 'ended', 'terminated', 'cancelled'] as const;
const RENT_FREQUENCIES = ['monthly', 'quarterly', 'annually'] as const;

export class TenancyQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page = 1;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  pageSize = 25;

  @IsOptional() @IsIn(TENANCY_STATUSES)
  status?: (typeof TENANCY_STATUSES)[number];
}

export class RentSchedulePreviewQueryDto {
  @Type(() => Number) @IsInt() @Min(2020) @Max(2100)
  year!: number;

  @Type(() => Number) @IsInt() @Min(1) @Max(12)
  month!: number;
}

export class CreateTenancyDto {
  @IsString() @MaxLength(254) @Matches(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  tenantEmail!: string;

  @IsString() @MaxLength(254) @Matches(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  payeeEmail!: string;

  @IsString() @MaxLength(16) @Matches(/^(?:0|[1-9]\d{0,9})(?:\.\d{1,2})?$/)
  rentAmount!: string;

  @IsString() @Matches(/^[A-Z]{3}$/)
  currency!: string;

  @IsString() @IsIn(RENT_FREQUENCIES)
  rentFrequency!: (typeof RENT_FREQUENCIES)[number];

  @Type(() => Number) @IsInt() @Min(1) @Max(31)
  rentDueDay!: number;

  @IsOptional() @IsString() @MaxLength(16) @Matches(/^(?:0|[1-9]\d{0,9})(?:\.\d{1,2})?$/)
  depositAmount?: string | null;

  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/)
  effectiveFrom!: string;

  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/)
  effectiveTo?: string | null;

  @IsOptional() @IsString() @MaxLength(2000)
  termsNote?: string | null;
}

export class ApproveTenancyDto {
  @IsString() @MaxLength(1000)
  reason!: string;
}

export class TerminateTenancyDto {
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/)
  effectiveTo!: string;

  @IsString() @MaxLength(1000)
  reason!: string;
}
